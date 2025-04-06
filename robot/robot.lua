local skynet = require "skynet"
local websocket = require "http.websocket"
local mysql = require "skynet.db.mysql"

local Robot = {}
Robot.__index = Robot

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

function Robot.new(id, user_info, host)
    local self = setmetatable({}, Robot)
    self.id = id
    -- 存储用户信息和agent信息
    self.socket_id = user_info.socket_id
    self.agent_handle = user_info.agent_handle
    self.host = host
    self.timer = nil
    self.state = "idle"  -- idle, active, sleeping
    self.message_count = 0
    
    -- 随机生成机器人属性
    self.age = math.random(18, 60)
    self.gender = (math.random(1, 2) == 1) and "male" or "female"
    
    -- 确保数据库连接初始化
    if not db then
        db = init_mysql()
    end
    
    -- 保存机器人数据到数据库
    self:save_to_db()
    
    return self
end

function Robot:save_to_db()
    if not db then
        db = init_mysql()
    end
    
    local sql = string.format(
        "INSERT INTO robot (robot_id, age, gender) VALUES (%d, %d, '%s') ON DUPLICATE KEY UPDATE age=%d, gender='%s'",
        self.id, self.age, self.gender, self.age, self.gender
    )
    
    local ok, err = pcall(function()
        return db:query(sql)
    end)
    
    if not ok then
        skynet.error("Failed to save robot data: ", err)
    else
        skynet.tracelog("mysql", string.format("Saved robot data: id=%d, age=%d, gender=%s", 
            self.id, self.age, self.gender))
    end
end

function Robot:link_to_user(user_id)
    if not db then
        db = init_mysql()
    end
    
    local sql = string.format(
        "INSERT INTO user_robot_link (user_id, robot_id) VALUES (%d, %d) ON DUPLICATE KEY UPDATE robot_id=robot_id",
        user_id, self.id
    )
    
    local ok, err = pcall(function()
        return db:query(sql)
    end)
    
    if not ok then
        skynet.error("Failed to link robot to user: ", err)
    else
        skynet.tracelog("mysql", string.format("Linked robot %d to user %d", self.id, user_id))
    end
end

function Robot:get_user_robots(user_id)
    if not db then
        db = init_mysql()
    end
    
    local sql = string.format([[
        SELECT r.* FROM robot r 
        INNER JOIN user_robot_link url ON r.robot_id = url.robot_id 
        WHERE url.user_id = %d
    ]], user_id)
    
    local ok, result = pcall(function()
        return db:query(sql)
    end)
    
    if not ok then
        skynet.error("Failed to get user robots: ", result)
        return {}
    end
    
    return result
end

function Robot:send_message(msg_type, content)
    if self.agent_handle and self.socket_id then
        skynet.send(self.agent_handle, "lua", "send_message", self.socket_id, msg_type, content)
    end
end

function Robot:start()
    self.timer = true
    self.state = "active"
    self:schedule_next_message()
end

function Robot:schedule_next_message()
    if not self.timer then return end
    
    -- 发送消息
    local messages = {
        string.format("robot [%d] says hello", self.id),
        string.format("robot [%d] is working", self.id),
        string.format("robot [%d] is thinking", self.id)
    }
    
    self.message_count = self.message_count + 1
    local message = messages[math.random(1, #messages)] .. " (msg #" .. self.message_count .. ")"
    
    -- 发送消息
    self:send_message(3, message)
    
    -- 随机延迟1-3秒
    local delay = math.random(100, 300)
    skynet.timeout(delay, function()
        if self.timer then
            -- 随机切换状态
            if math.random() < 0.2 then  -- 20%概率切换状态
                if self.state == "active" then
                    self.state = "sleeping"
                    local status_msg = string.format("robot [%d] is now sleeping", self.id)
                    self:send_message(3, status_msg)
                    
                    -- 3秒后醒来
                    skynet.timeout(300, function()
                        if self.timer then
                            self.state = "active"
                            local wake_msg = string.format("robot [%d] woke up", self.id)
                            self:send_message(3, wake_msg)
                            self:schedule_next_message()
                        end
                    end)
                    return
                end
            end
            self:schedule_next_message()
        end
    end)
end

function Robot:stop()
    self.timer = false
    self.state = "idle"
    -- 发送停止消息
    local stop_msg = string.format("robot [%d] stopped", self.id)
    self:send_message(3, stop_msg)
end

return Robot 