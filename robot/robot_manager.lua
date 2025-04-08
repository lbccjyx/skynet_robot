local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local Robot = require "robot"

local RobotManager = {}
RobotManager.__index = RobotManager

-- 数据库连接实例
local db

-- 初始化数据库连接
local function init_mysql()
    if not db then
        db = mysql.connect({
            host = "127.0.0.1",
            port = 3306,
            database = "PlayerDatabase",
            user = "skynet",
            password = "Password123",
            max_packet_size = 1024 * 1024,
            on_connect = function(db)
                db:query("set charset utf8")
            end
        })
        assert(db, "failed to connect to mysql")
        skynet.tracelog("mysql", "Database connection initialized")
    end
    return db
end

function RobotManager.new()
    local self = setmetatable({}, RobotManager)
    self.robots = {}  -- 存储当前玩家的机器人实例
    return self
end

-- 初始化玩家的机器人
function RobotManager:init(user_id, agent_handle, socket_id, host)
    skynet.tracelog("robot_manager", string.format("Initializing robots for user %d", user_id))
    self.user_id = user_id
    self.host = host
    
    -- 保存用户信息
    self.user_info = {
        user_id = user_id,
        socket_id = socket_id,
        agent_handle = agent_handle
    }
    
    -- 加载玩家的机器人
    return self:load_user_robots()
end

-- 从数据库加载玩家的机器人
function RobotManager:load_user_robots()
    if not db then
        db = init_mysql()
    end
    
    -- 查询玩家的所有机器人
    local sql = string.format([[
        SELECT r.* FROM d_robot r 
        INNER JOIN d_user_robot_link url ON r.robot_id = url.robot_id 
        WHERE url.user_id = %d
    ]], self.user_id)
    
    local ok, result = pcall(function()
        return db:query(sql)
    end)
    
    if not ok then
        skynet.error("Failed to load user robots: ", result)
        return false
    end
    
    -- 清空现有机器人
    self:stop_all_robots()
    self.robots = {}
    
    -- 创建机器人实例
    for _, robot_data in ipairs(result) do
        local robot = Robot.new(robot_data.robot_id, self.user_info, self.host)
        robot.age = robot_data.age
        robot.gender = robot_data.gender
        self.robots[robot_data.robot_id] = robot
        robot:start()  -- 启动机器人
        skynet.tracelog("robot_manager", string.format("Loaded robot: id=%d, age=%d, gender=%s", 
            robot_data.robot_id, robot_data.age, robot_data.gender))
    end
    
    return true
end

-- 创建新机器人
function RobotManager:create_robot(robot_id)
    if self.robots[robot_id] then
        skynet.error("Robot already exists: ", robot_id)
        return false
    end
    
    local robot = Robot.new(robot_id, self.user_info, self.host)
    robot.age = math.random(18, 60)
    robot.gender = (math.random(1, 2) == 1) and "male" or "female"
    
    -- 保存到数据库
    if not db then
        db = init_mysql()
    end
    
    -- 保存机器人数据
    local sql = string.format(
        "INSERT INTO d_robot (robot_id, age, gender) VALUES (%d, %d, '%s')",
        robot_id, robot.age, robot.gender
    )
    
    local ok, err = pcall(function()
        return db:query(sql)
    end)
    
    if not ok then
        skynet.error("Failed to save robot data: ", err)
        return false
    end
    
    -- 关联到用户
    sql = string.format(
        "INSERT INTO d_user_robot_link (user_id, robot_id) VALUES (%d, %d)",
        self.user_id, robot_id
    )
    
    ok, err = pcall(function()
        return db:query(sql)
    end)
    
    if not ok then
        skynet.error("Failed to link robot to user: ", err)
        -- 删除已创建的机器人数据
        db:query(string.format("DELETE FROM d_robot WHERE robot_id = %d", robot_id))
        return false
    end
    
    self.robots[robot_id] = robot
    robot:start()
    
    return true
end

-- 停止所有机器人
function RobotManager:stop_all_robots()
    for _, robot in pairs(self.robots) do
        robot:stop()
    end
end

-- 获取机器人数量
function RobotManager:get_robot_count()
    local count = 0
    for _ in pairs(self.robots) do
        count = count + 1
    end
    return count
end

-- 获取指定ID的机器人
function RobotManager:get_robot(robot_id)
    return self.robots[robot_id]
end

-- 获取所有机器人
function RobotManager:get_all_robots()
    return self.robots
end

return RobotManager 