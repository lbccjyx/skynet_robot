local skynet = require "skynet"

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

return CUser 