local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local WSServer = {}
WSServer.__index = WSServer

function WSServer.new()
    local self = setmetatable({}, WSServer)
    self.handlers = {}  -- 消息处理器
    self.clients = {}   -- 客户端连接
    self.handshake_handler = nil  -- handshake处理函数
    return self
end

-- 设置handshake处理器
function WSServer:set_handshake_handler(handler)
    self.handshake_handler = handler
end

-- 设置客户端用户ID
function WSServer:set_client_user_id(client_id, user_id)
    if self.clients[client_id] then
        self.clients[client_id].user_id = user_id
    end
end

-- 注册消息处理器
function WSServer:register_handler(msg_type, handler)
    self.handlers[msg_type] = handler
end

-- 处理WebSocket连接
function WSServer:handle_socket(id, protocol, addr)
    if protocol:lower() ~= "ws" then
        socket.close(id)
        return
    end

    local handle = {
        connect = function(id)
            skynet.tracelog("connect", string.format("ws connect from: %s", tostring(id)))
            self.clients[id] = { id = id }
        end,

        handshake = function(id, header, url)
            if self.handshake_handler then
                return self.handshake_handler(id, header, url)
            end
            return true
        end,

        message = function(id, msg, msg_type)
            assert(msg_type == "binary" or msg_type == "text")
            
            -- 解析二进制消息
            local type = string.unpack("<i4", msg, 1)
            local msg_len = string.unpack("<i4", msg, 5)
            local message = string.sub(msg, 9)
            
            -- 调用对应的处理器
            local handler = self.handlers[type]
            if handler then
                local response = handler(self.clients[id], message)
                if response then
                    self:send_message(id, type, response)
                end
            else
                skynet.error("Unknown message type:", type)
            end
        end,

        ping = function(id)
            skynet.tracelog("ping", string.format("ws ping from: %s", tostring(id)))
        end,

        pong = function(id)
            skynet.tracelog("pong", string.format("ws pong from: %s", tostring(id)))
        end,

        close = function(id, code, reason)
            skynet.tracelog("close", string.format("ws close from: %s", tostring(id)))
            if self.clients[id] then
                if self.on_client_disconnect then
                    self.on_client_disconnect(self.clients[id])
                end
                self.clients[id] = nil
            end
        end,

        error = function(id)
            skynet.tracelog("error", string.format("ws error from: %s", tostring(id)))
            if self.clients[id] then
                if self.on_client_error then
                    self.on_client_error(self.clients[id])
                end
                self.clients[id] = nil
            end
        end
    }

    local ok, err = websocket.accept(id, handle, "ws", addr)
    if not ok then
        skynet.tracelog("websocket", string.format("websocket accept failed: %s", err))
        socket.close(id)
    end
end

-- 发送消息
function WSServer:send_message(client_id, msg_type, content)
    if not self.clients[client_id] then
        return false
    end

    local ok, err = pcall(function()
        local resp_buffer = string.pack("<i4i4", msg_type, #content) .. content
        websocket.write(client_id, resp_buffer, "binary")
    end)

    if not ok then
        skynet.error("Failed to send message:", err)
        return false
    end
    return true
end

-- 关闭客户端连接
function WSServer:close_client(client_id)
    if self.clients[client_id] then
        pcall(websocket.close, client_id)
        self.clients[client_id] = nil
    end
end

-- 设置客户端断开连接回调
function WSServer:set_disconnect_callback(callback)
    self.on_client_disconnect = callback
end

-- 设置客户端错误回调
function WSServer:set_error_callback(callback)
    self.on_client_error = callback
end

return WSServer 