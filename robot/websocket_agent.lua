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
local ProtoLoader = require "proto_loader"

skynet.init(function()
    -- 加载sproto文件
    -- 如果是多线程环境，建议这样使用：
    local loader = ProtoLoader:new()
    local ok, sproto_obj = pcall(loader.get_sproto, loader)
    if not ok then
        skynet.error("Failed to create sproto object")
        return
    end    
    host = sproto_obj:host "package"
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
            -- skynet.tracelog("handshake", string.format("Invalid token: %s", token))
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
    message_router:register_handler(sproto_obj:queryproto("PROTOCOL_NORMAL_REQ").tag, function(client, message)
        local msg_type = message.type
        local content = message.message
        if msg_type == Enums.MSG_TYPE.ECHO then
            return content
        elseif msg_type == Enums.MSG_TYPE.ROBOT_CTRL then
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
        elseif msg_type == Enums.MSG_TYPE.BUILD_INFO then
            local struct_id = tonumber(message)
            if struct_id and struct_id > 0 then
                local struct_config = GetCfgByIndex("s_struct","str_name", struct_id);
                if struct_config ~= nil then
                    return struct_config["cn_name"]
                end
            end
        end
        return "Unknown message type"
    end)

    -- message_router:register_handler(sproto_obj:queryproto("PROTOCOL_NORMAL_POS_C_TO_S").tag, function(client, message)
    --     local Lux = message.pos_L_U_x
    --     local Luy = message.pos_L_U_y
    --     local Rux = message.pos_R_U_x
    --     local Ruy = message.pos_R_U_y
    --     local Rdx = message.pos_R_D_x
    --     local Rdy = message.pos_R_D_y
    --     local Ldx = message.pos_L_D_x
    --     local Ldy = message.pos_L_D_y
    --     return "我已收到城墙坐标"
    -- end)



    message_router:init()
end)

-- 处理skynet消息
skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        if cmd == "socket" then
            local id, protocol, addr = ...
            ws_server:handle_socket(id, protocol, addr)
        elseif cmd == "send_message" then
            local socket_id, proto_name, content = ...
            local ok = ws_server:send_message(socket_id, proto_name, content)
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