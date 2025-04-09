local skynet = require "skynet"
local sproto = require "sproto"
local sprotoparser = require "sprotoparser"
local WSServer = require "core.ws_server"
local MessageRouter = require "core.message_router"
local RobotManager = require "robot_manager"
local CUser = require "user"
local DBManager = require "core.db_manager"
local ConfigManager = require "core.config_manager"
local ws_server
local message_router
local host
local Enums = require "core.enums"

skynet.init(function()
    -- 加载sproto文件
    local f = io.open("./robot/proto/ws.sproto", "r")
    local content = f:read("*a")
    f:close()
    
    local sp = sprotoparser.parse(content)
    host = sproto.new(sp):host "package"

    -- 初始化数据库连接
    local db = DBManager.getInstance()
    local ok, err = db:init()
    if not ok then
        skynet.error("Failed to initialize database:", err)
        -- 不阻止服务启动，让它在需要时重试
    end

    -- 初始化WebSocket服务器
    ws_server = WSServer.new()
    message_router = MessageRouter.new(ws_server)

    -- 设置handshake处理
    ws_server:set_handshake_handler(function(id, header, url)
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

        -- 设置客户端用户ID
        ws_server:set_client_user_id(id, user_id)
        return true
    end)

    -- 注册消息处理器
    message_router:register_handler(Enums.MSG_TYPE.ECHO, function(client, message)
        return message
    end)

    message_router:register_handler(Enums.MSG_TYPE.ROBOT_CTRL, function(client, message)
        local count = tonumber(message)
        if count and count > 0 and client.user_id then
            local robot_mgr_addr = tonumber(skynet.getenv("SKYNET_ROBOT_MGR_SERVICE"))
            if not robot_mgr_addr then
                return "Robot manager service not found"
            end
            local created_count = skynet.call(robot_mgr_addr, "lua", "create_robots", client.user_id, count)
            return string.format("Created %d robots", created_count)
        end
        return "Invalid robot count or user not initialized"
    end)

    message_router:register_handler(Enums.MSG_TYPE.BUILD_INFO, function(client, message)
        skynet.error("Build formation: ", message)
        local struct_config = GetCfgByIndex("s_struct","str_name", message);
        if struct_config ~= nil then
            local str = string.format("%s,%s,%s", struct_config["cn_name"], struct_config["id"], struct_config["str_name"])
            return str
        end
        return "Invalid struct id"
    end)

    message_router:init()
end)

-- 处理skynet消息
skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        if cmd == "socket" then
            local id, protocol, addr = ...
            ws_server:handle_socket(id, protocol, addr)
        elseif cmd == "send_message" then
            local socket_id, msg_type, content = ...
            local ok = ws_server:send_message(socket_id, msg_type, content)
            skynet.ret(skynet.pack(ok))
        elseif cmd == "close" then
            local socket_id = ...
            ws_server:close_client(socket_id)
            skynet.ret(skynet.pack(true))
        else
            skynet.error("Unknown command: ", cmd)
        end
    end)
end) 