local skynet = require "skynet"
local websocket = require "http.websocket"
local DBManager = require "core.db_manager"

local Robot = {}
Robot.__index = Robot

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
    
    -- 保存机器人数据到数据库
    self:save_to_db()
    
    return self
end

function Robot:save_to_db()
    local db = DBManager.getInstance()
    local ok, result = db:query(
        "INSERT INTO d_user_robot (robot_id, age, gender) VALUES (%d, %d, '%s') ON DUPLICATE KEY UPDATE age=%d, gender='%s'",
        self.id, self.age, self.gender, self.age, self.gender
    )
    
    if not ok then
        skynet.error("Failed to save robot data: ", result)
    else
        skynet.tracelog("mysql", string.format("Saved robot data: id=%d, age=%d, gender=%s", 
            self.id, self.age, self.gender))
    end
end

function Robot:link_to_user(user_id)
    local db = DBManager.getInstance()
    local ok, result = db:query(
        "INSERT INTO d_user_robot_link (user_id, robot_id) VALUES (%d, %d) ON DUPLICATE KEY UPDATE robot_id=robot_id",
        user_id, self.id
    )
    
    if not ok then
        skynet.error("Failed to link robot to user: ", result)
    else
        skynet.tracelog("mysql", string.format("Linked robot %d to user %d", self.id, user_id))
    end
end

function Robot:get_user_robots(user_id)
    local db = DBManager.getInstance()
    local ok, result = db:query([[
        SELECT r.* FROM d_user_robot r 
        INNER JOIN d_user_robot_link url ON r.robot_id = url.robot_id 
        WHERE url.user_id = %d
    ]], user_id)
    
    if not ok then
        skynet.error("Failed to get user robots: ", result)
        return {}
    end
    
    return result
end

function Robot:send_message(msg_type, content)
    if self.agent_handle and self.socket_id then
        skynet.send(self.agent_handle, "lua", "send_message", self.socket_id, "WsMessage",{
            type = msg_type,
            message = content
        })
    end
end

function Robot:start()
    skynet.error("robot_say_hello: ", skynet.getenv("robot_say_hello"))
    if skynet.getenv("robot_say_hello") == "true" then
        self.timer = true
        self.state = "active"
        self:schedule_next_message()
    end
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