local skynet = require "skynet"
local socket = require "skynet.socket"
local ConfigManager = require "core.config_manager"
local DBManager = require "core.db_manager"

local function create_agent_pool()
    local agent = {}
    for i = 1, 20 do
        local ok, handle = pcall(skynet.newservice, "websocket_agent")
        if not ok then
            skynet.error("Failed to create websocket_agent:", handle)
            -- 继续创建其他agent
        else
            agent[#agent + 1] = handle
        end
    end
    return agent
end

skynet.start(function()
    -- 初始化数据库连接
    local db = DBManager.getInstance()
    local ok, err = db:init()
    if not ok then
        skynet.error("Failed to initialize database connection:", err)
        skynet.exit()
        return
    end
    skynet.error("Database connection initialized successfully")
    
    -- 初始化配置管理器
    local config_manager = ConfigManager.getInstance()
    ok, err = config_manager:init()
    if not ok then
        skynet.error("Failed to initialize config manager:", err)
    else
        skynet.error("Config manager initialized successfully")
    end
    
    -- 启动用户管理服务
    local user_mgr = skynet.newservice("user_mgr_service")
    skynet.setenv("SKYNET_USER_MGR_ADDR", tostring(user_mgr))
    skynet.tracelog("init", string.format("robot user_mgr service started with handle: %s", user_mgr))
    
    -- 启动机器人管理服务
    local robot_mgr = skynet.newservice("robot_manager_service")
    skynet.setenv("SKYNET_ROBOT_MGR_SERVICE", tostring(robot_mgr))
    skynet.tracelog("init", string.format("robot robot_manager service started with handle: %s", robot_mgr))

    -- 启动登录服务
    local login = skynet.newservice("login_service")
    skynet.tracelog("init", string.format("login service started: %s", login))

    -- 创建 websocket agent 池
    local agent = create_agent_pool()
    if #agent == 0 then
        skynet.error("No websocket agents created, service cannot start")
        skynet.exit()
        return
    end
    
    local balance = 1

    -- 获取WebSocket配置
    local ws_port = tonumber(skynet.getenv("websocket_port")) or 9948
    local ws_host = skynet.getenv("websocket_host") or "0.0.0.0"

    -- 监听 WebSocket 连接
    local ok, id = pcall(socket.listen, ws_host, ws_port)
    if not ok then
        skynet.error("Failed to listen on " .. ws_host .. ":" .. ws_port .. ": " .. id)
        skynet.exit()
        return
    end

    skynet.error(string.format("Listen websocket port %d", ws_port))
    socket.start(id, function(id, addr)
        -- skynet.tracelog("accept", string.format("accept client socket_id: %s addr: %s", id, addr))
        -- 使用socket命令处理websocket连接
        skynet.send(agent[balance], "lua", "socket", id, "ws", addr)
        balance = balance + 1
        if balance > #agent then
            balance = 1
        end
    end)
end) 