local skynet = require "skynet"

local MessageRouter = {}
MessageRouter.__index = MessageRouter

function MessageRouter.new(ws_server)
    local self = setmetatable({}, MessageRouter)
    self.ws_server = ws_server
    self.handlers = {}
    return self
end

-- 注册消息处理器
function MessageRouter:register_handler(msg_type, handler)
    self.handlers[msg_type] = handler
end

-- 初始化路由
function MessageRouter:init()
    -- 注册到WebSocket服务器
    for msg_type, _ in pairs(self.handlers) do
        self.ws_server:register_handler(msg_type, function(client, message)
            return self:route_message(msg_type, client, message)
        end)
    end
end

-- 路由消息
function MessageRouter:route_message(msg_type, client, message)
    local handler = self.handlers[msg_type]
    if handler then
        return handler(client, message)
    else
        skynet.error("No handler registered for message type:", msg_type)
        return "Unknown message type"
    end
end

-- 广播消息
function MessageRouter:broadcast(msg_type, content)
    for client_id, _ in pairs(self.ws_server.clients) do
        self.ws_server:send_message(client_id, msg_type, content)
    end
end

return MessageRouter 