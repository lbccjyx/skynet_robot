local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local sproto = require "sproto"
local sprotoparser = require "sprotoparser"

local WSServer = {}
WSServer.__index = WSServer

function WSServer.new()
    local self = setmetatable({}, WSServer)
    self.handlers = {}  -- 消息处理器
    self.clients = {}   -- 客户端连接
    self.handshake_handler = nil  -- handshake处理函数
    
    -- 加载并解析sproto
    local sp_file = io.open("robot/proto/ws.sproto", "r")
    local sp_data = sp_file:read("*a")
    sp_file:close()
    self.sproto_schema = sprotoparser.parse(sp_data)
    self.sproto = sproto.new(self.sproto_schema)
    
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
            
            -- 使用pcall包装所有可能出错的操作
            local ok, err = pcall(function()
                -- 解析二进制消息
                skynet.tracelog("websocket", string.format("收到客户端消息，client_id: %d, msg_type: %s, msg_len: %d", id, msg_type, #msg))
                
                local proto_id = string.unpack("<i4", msg, 1)
                local msg_len = string.unpack("<i4", msg, 5)
                local raw_message = string.sub(msg, 9)
                
                skynet.tracelog("websocket", string.format("解析消息头，proto_id: %d, msg_len: %d", proto_id, msg_len))
                
                -- 获取协议名称
                local proto = self.sproto.queryproto(proto_id)
                if not proto then
                    skynet.error(string.format("未知的协议ID: %d", proto_id))
                    return
                end
                
                local proto_name = proto.pname
                skynet.tracelog("websocket", string.format("协议名称: %s", proto_name))
                
                -- 解码消息内容
                local decoded_message = self.sproto:decode(proto_name, raw_message)
                if not decoded_message then
                    skynet.error(string.format("消息解码失败，proto_name: %s, raw_message_len: %d", proto_name, #raw_message))
                    return
                end
                
                skynet.tracelog("websocket", string.format("消息解码成功: %s", table.concat(table.pack(decoded_message), ", ")))
                
                -- 调用对应的处理器
                local handler = self.handlers[proto_id]
                if handler then
                    -- 传递解码后的消息给handler
                    local response = handler(self.clients[id], decoded_message)
                    -- 默认收到消息之后要回复消息
                    if response then
                        skynet.tracelog("websocket", string.format("发送响应消息，client_id: %d", id))
                        self:send_message(id, "NormalResp", {resp = response})
                    end
                else
                    skynet.error(string.format("未找到协议处理器: %s (id: %d)", proto_name, proto_id))
                end
            end)
            
            if not ok then
                skynet.error(string.format("处理消息时发生错误: %s", tostring(err)))
                -- 不要断开连接，只记录错误
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
function WSServer:send_message(client_id, proto_name, data)
    if not self.clients[client_id] then
        return false
    end

    local ok, err = pcall(function()
        -- 使用sproto序列化数据
        local message = self.sproto:encode(proto_name, data)
        if not message then
            error("Failed to encode message with proto: " .. proto_name)
        end
        
        -- 获取协议ID
        local proto_id = assert(self.sproto.queryproto(proto_name).tag, "Unknown protocol: " .. proto_name)
        
        -- 构建二进制消息：proto_id(4字节) + 消息长度(4字节) + 消息内容
        local resp_buffer = string.pack("<i4i4", proto_id, #message) .. message
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