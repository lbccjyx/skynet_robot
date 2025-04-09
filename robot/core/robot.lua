local skynet = require "skynet"
local message_router = require "core.message_router"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"

local Robot = {}
Robot.__index = Robot

function Robot.new(ws_server)
    local self = setmetatable({}, Robot)
    self.ws_server = ws_server
    self.router = message_router.new(ws_server)
    self.robots = {}  -- 存储所有机器人
    self.bounds = nil  -- 存储城墙边界
    self.total_steps = 100  -- 绕城墙一圈需要的步数
    
    -- 加载sproto协议
    local host = sprotoloader.load(1)
    self.host = host
    self.send_request = host:attach(host:dispatch())
    
    return self
end

function Robot:init()
    self.router:register_handler(1, function(client, message)
        -- 处理NormalPos消息
        local request = self.host:dispatch(message)
        local normalPos = request[2]
        
        self.bounds = {
            left = normalPos.pos_L_U_x,
            top = normalPos.pos_L_U_y,
            right = normalPos.pos_R_U_x,
            bottom = normalPos.pos_L_D_y
        }
        
        -- 计算移动速度
        local perimeter = (self.bounds.right - self.bounds.left) * 2 + 
                         (self.bounds.bottom - self.bounds.top) * 2
        local step_size = perimeter / self.total_steps
        
        -- 初始化机器人
        self:init_robots(step_size)
        
        return "OK"
    end)
    
    self.router:init()
end

function Robot:init_robots(step_size)
    -- 创建10个机器人
    for i = 1, 10 do
        self.robots[i] = {
            id = i,
            x = self.bounds.left,
            y = self.bounds.top,
            step = 0,
            direction = 1,  -- 1:右, 2:下, 3:左, 4:上
            step_size = step_size
        }
    end
    
    -- 启动定时器发送位置更新
    skynet.timeout(100, function()
        self:update_positions()
    end)
end

function Robot:update_positions()
    for _, robot in pairs(self.robots) do
        -- 更新位置
        if robot.direction == 1 then  -- 向右
            robot.x = robot.x + robot.step_size
            if robot.x >= self.bounds.right then
                robot.x = self.bounds.right
                robot.direction = 2
            end
        elseif robot.direction == 2 then  -- 向下
            robot.y = robot.y + robot.step_size
            if robot.y >= self.bounds.bottom then
                robot.y = self.bounds.bottom
                robot.direction = 3
            end
        elseif robot.direction == 3 then  -- 向左
            robot.x = robot.x - robot.step_size
            if robot.x <= self.bounds.left then
                robot.x = self.bounds.left
                robot.direction = 4
            end
        else  -- 向上
            robot.y = robot.y - robot.step_size
            if robot.y <= self.bounds.top then
                robot.y = self.bounds.top
                robot.direction = 1
            end
        end
        
        -- 发送位置更新
        local robotPos = {
            robot_id = robot.id,
            posX = math.floor(robot.x),
            posY = math.floor(robot.y),
            speed = robot.step_size,
            status = robot.direction,
            robot_total_num = 10
        }
        
        -- 使用sproto协议发送消息
        local message = self.send_request("RobotPos", robotPos)
        self.ws_server:broadcast_message(2, message)
    end
    
    -- 继续下一次更新
    skynet.timeout(100, function()
        self:update_positions()
    end)
end

return Robot 