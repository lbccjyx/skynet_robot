local skynet = require "skynet"
local DBManager = require "core.db_manager"

local CUser = {}
CUser.__index = CUser

function CUser.new(user_id, socket_id, agent_handle)
    local self = setmetatable({}, CUser)
    self.user_id = user_id
    self.socket_id = socket_id
    self.agent_handle = agent_handle  -- websocket agent的服务句柄
    return self
end

-- 发送消息
function CUser:send_message(msg_type, content)
    if self.agent_handle and self.socket_id then
        return skynet.call(self.agent_handle, "lua", "send_message", self.socket_id, msg_type, content)
    end
    return false
end

-- 数据库操作
function CUser:save_to_db()
    local db = DBManager.getInstance()
    local ok, result = db:query(
        "INSERT INTO users (user_id, last_login) VALUES (%d, NOW()) ON DUPLICATE KEY UPDATE last_login=NOW()",
        self.user_id
    )
    
    if not ok then
        return false, result
    end
    return true
end

function CUser:load_from_db()
    local db = DBManager.getInstance()
    local ok, result = db:query("SELECT * FROM users WHERE user_id = %d", self.user_id)
    
    if not ok then
        return false, result
    end
    
    if result and result[1] then
        self.user_data = result[1]
        return true
    end
    return false, "User not found"
end

-- 清理资源
function CUser:cleanup()
    if self.agent_handle and self.socket_id then
        pcall(skynet.call, self.agent_handle, "lua", "close", self.socket_id)
    end
end

return CUser 