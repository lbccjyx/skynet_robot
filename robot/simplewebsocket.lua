local skynet = require "skynet"
local socket = require "skynet.socket"
local service = require "skynet.service"
local websocket = require "http.websocket"
local sproto = require "sproto"
local sprotoparser = require "sprotoparser"
local RobotManager = require "robot_manager"

local handle = {}
local MODE = ...
local host
local client_id = nil  -- 存储当前连接的客户端ID
local current_user_id = nil  -- 存储当前用户ID

-- 无效调试 require "debugger":start "127.0.0.1:8172":event "wait"

if MODE == "agent" then
    -- 创建机器人的函数
    local function create_robots(count)
        -- 停止并清空现有机器人
        for _, robot in pairs(robots) do
            robot:stop()
        end
        robots = {}
        
        -- 创建新的机器人
        for i = 1, count do
            local robot = Robot.new(i, websocket, client_id, host)
            robots[i] = robot
            robot:start()  -- 启动机器人的定时器
        end
    end

    -- 发送消息到客户端
    local function send_message(socket_id, msg_type, content)
        if socket_id and socket_id == client_id then  -- 确保socket_id有效且匹配当前客户端
            local ok, err = pcall(function()
                local resp_buffer = string.pack("<i4i4", msg_type, #content) .. content
                websocket.write(socket_id, resp_buffer, "binary")
            end)
            if not ok then
                skynet.error("Failed to send message:", err)
                return false
            end
            return true
        end
        return false
    end

    skynet.init(function()
        -- 加载sproto文件
        local f = io.open("./examples/proto/ws.sproto", "r")
        local content = f:read("*a")
        f:close()
        
        local sp = sprotoparser.parse(content)
        host = sproto.new(sp):host "package"
    end)

    -- 添加消息处理函数
    local function process_socket(id, protocol, addr)
        skynet.tracelog("websocket", string.format("process_socket start: %s %s %s", id, protocol, addr))
        if type(protocol) == "string" and protocol:lower() == "ws" then
            skynet.tracelog("websocket", "attempting websocket accept")
            local ok, err = websocket.accept(id, handle, "ws", addr)
            if not ok then
                skynet.tracelog("websocket", string.format("websocket accept failed: %s", err))
                socket.close(id)
            else
                skynet.tracelog("websocket", "websocket accept successful")
            end
        else
            socket.close(id)
        end
    end

    -- 添加消息分发
    skynet.start(function()
        skynet.dispatch("lua", function(session, source, cmd, ...)
            if cmd == "send_message" then
                -- 处理发送消息请求
                local socket_id, msg_type, content = ...
                local ok = send_message(socket_id, msg_type, content)
                skynet.ret(skynet.pack(ok))
            elseif cmd == "socket" then
                -- 处理websocket连接请求
                local id, protocol, addr = ...
                process_socket(id, protocol, addr)
            else
                skynet.error("Unknown command: ", cmd)
            end
        end)
    end)

    function handle.connect(id)
        skynet.tracelog("connect", string.format("ws connect from: %s", tostring(id)))
        client_id = id  -- 保存客户端ID
    end

    function handle.handshake(id, header, url)
        -- 解析URL中的token参数
        local token = url:match("token=([^&]+)")
        if not token then
            skynet.tracelog("handshake", "No token provided in URL")
            return false
        end

        -- 验证token
        local user_mgr_addr = tonumber(skynet.getenv("SKYNET_USER_MGR_ADDR"))
        if not user_mgr_addr then
            skynet.tracelog("handshake", "User manager service not found")
            return false
        end

        -- 获取用户ID
        local user_id = skynet.call(user_mgr_addr, "lua", "verify_token", token)
        if not user_id then
            skynet.tracelog("handshake", string.format("Invalid token: %s", token))
            return false
        end

        -- 初始化机器人管理器
        local robot_mgr_addr = tonumber(skynet.getenv("SKYNET_ROBOT_MGR_SERVICE"))
        if not robot_mgr_addr then
            skynet.tracelog("handshake", "Robot manager service not found")
            return false
        end

        -- 添加在线用户
        local ok = skynet.call(user_mgr_addr, "lua", "add_online_user", user_id, id, skynet.self(), token)
        if not ok then
            skynet.tracelog("handshake", "Failed to add online user")
            return false
        end

        -- 初始化机器人管理器
        local init_ok = skynet.call(robot_mgr_addr, "lua", "init_manager", user_id, skynet.self(), id)
        if not init_ok then
            skynet.tracelog("handshake", "Failed to initialize robot manager")
            return false
        end

        current_user_id = user_id
        client_id = id

        skynet.tracelog("handshake", string.format("Token verified for user_id: %s", user_id))
        return true
    end

    function handle.message(id, msg, msg_type)
        skynet.tracelog("message", "handle.message")
        assert(msg_type == "binary" or msg_type == "text")
        
        -- 解析二进制消息
        local type = string.unpack("<i4", msg, 1)
        local msg_len = string.unpack("<i4", msg, 5)
        local message = string.sub(msg, 9)
        
        skynet.tracelog("message", string.format("Received message type: %s content: %s", type, message))

        -- 构造响应
        local response = {
            type = type,
            message = message
        }

        if type == 1 then
            skynet.tracelog("message", "request.type == 1")
            -- type 1: 回显消息
            local response_message = message
            -- 构造二进制响应
            local resp_buffer = string.pack("<i4i4", type, #response_message) .. response_message
            skynet.tracelog("message", string.format("Sending response: type=%s length=%s message=%s", 
                type, #response_message, response_message))
            websocket.write(id, resp_buffer, "binary")
        elseif type == 2 then
            skynet.tracelog("message", "request.type == 2")
            -- type 2: 创建机器人
            local count = tonumber(message)
            if count and count > 0 and current_user_id then
                local robot_mgr_addr = tonumber(skynet.getenv("SKYNET_ROBOT_MGR_SERVICE"))
                if not robot_mgr_addr then
                    response.message = "Robot manager service not found"
                else
                    local created_count = skynet.call(robot_mgr_addr, "lua", "create_robots", current_user_id, count)
                    response.message = string.format("Created %d robots", created_count)
                end
            else
                response.message = "Invalid robot count or user not initialized"
            end
            local resp_buffer = string.pack("<i4i4", type, #response.message) .. response.message
            websocket.write(id, resp_buffer, "binary")
        else
            -- 未知类型
            response.message = "Unknown message type: " .. tostring(type)
            local resp_buffer = string.pack("<i4i4", type, #response.message) .. response.message
            websocket.write(id, resp_buffer, "binary")
        end
    end

    function handle.ping(id)
        skynet.tracelog("ping", string.format("ws ping from: %s", tostring(id)))
    end

    function handle.pong(id)
        skynet.tracelog("pong", string.format("ws pong from: %s", tostring(id)))
    end

    function handle.close(id, code, reason)
        skynet.tracelog("close", string.format("ws close from: %s code: %s reason: %s", tostring(id), code, reason))
        if id == client_id then
            -- 清理机器人
            if current_user_id then
                local robot_mgr_addr = tonumber(skynet.getenv("SKYNET_ROBOT_MGR_SERVICE"))
                if robot_mgr_addr then
                    skynet.send(robot_mgr_addr, "lua", "cleanup_user", current_user_id)  -- 改用send避免等待
                end
                current_user_id = nil
            end
            client_id = nil  -- 立即清除client_id
        end
    end

    function handle.error(id)
        skynet.tracelog("error", string.format("ws error from: %s", tostring(id)))
        if id == client_id then
            -- 清理机器人
            if current_user_id then
                local robot_mgr_addr = tonumber(skynet.getenv("SKYNET_ROBOT_MGR_SERVICE"))
                if robot_mgr_addr then
                    skynet.call(robot_mgr_addr, "lua", "cleanup_user", current_user_id)
                end
                current_user_id = nil
            end
            client_id = nil
        end
    end

    -- 添加踢出客户端的处理函数
    function handle.kick_client(socket_id)
        skynet.tracelog("kick", string.format("kick_client called for socket_id: %s", socket_id))
        if socket_id and socket_id == client_id then
            skynet.tracelog("kick", string.format("kicking client: %s", socket_id))
            -- 停止所有机器人
            if current_user_id then
                local robot_mgr_addr = tonumber(skynet.getenv("SKYNET_ROBOT_MGR_SERVICE"))
                if robot_mgr_addr then
                    skynet.call(robot_mgr_addr, "lua", "cleanup_user", current_user_id)
                end
                current_user_id = nil
            end
            
            -- 发送踢出消息给客户端
            local kick_msg = string.pack("<i4i4", 4, #"Account logged in elsewhere") .. "Account logged in elsewhere"
            websocket.write(socket_id, kick_msg, "binary")
            
            -- 关闭连接
            skynet.sleep(100)  -- 等待消息发送完成
            websocket.close(socket_id)
        else
            skynet.tracelog("kick", string.format("socket_id not match current client_id: %s %s", socket_id, client_id))
        end
    end

else
    skynet.start(function ()
        -- 先启动用户管理服务
        local user_mgr = skynet.newservice("user_mgr_service")
        -- 将服务地址存入环境变量（进程级全局）
        skynet.setenv("SKYNET_USER_MGR_ADDR", tostring(user_mgr))
        skynet.tracelog("init", string.format("robot user_mgr service started with handle: %s", user_mgr))
        
        -- 启动机器人管理服务
        local robot_mgr = skynet.newservice("robot_manager_service")
        skynet.setenv("SKYNET_ROBOT_MGR_SERVICE", tostring(robot_mgr))
        skynet.tracelog("init", string.format("robot robot_manager service started with handle: %s", robot_mgr))

        -- 启动登录服务
        local login = skynet.newservice("login_service")
        skynet.tracelog("init", string.format("login service started: %s", login))

        -- 创建 agent 池
        local agent = {}
        for i= 1, 20 do
            agent[i] = skynet.newservice(SERVICE_NAME, "agent")
        end
        local balance = 1

        -- 监听 WebSocket 连接
        local id = socket.listen("0.0.0.0", 9948)
        skynet.error(string.format("Listen websocket port 9948"))
        socket.start(id, function(id, addr)
            skynet.tracelog("accept", string.format("accept client socket_id: %s addr: %s", id, addr))
            -- 使用socket命令处理websocket连接
            skynet.send(agent[balance], "lua", "socket", id, "ws", addr)
            balance = balance + 1
            if balance > #agent then
                balance = 1
            end
        end)
    end)
end
