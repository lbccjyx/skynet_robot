local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local sproto = require "sproto"
local sprotoparser = require "sprotoparser"

local db
local host

skynet.init(function()
    -- 加载sproto文件
    local f = io.open("./robot/proto/ws.sproto", "r")
    local content = f:read("*a")
    f:close()
    
    local sp = sprotoparser.parse(content)
    host = sproto.new(sp):host "package"
    
end)

local function init_mysql()
    db = mysql.connect({
        host = "127.0.0.1",
        port = 3306,
        database = "PlayerDatabase",
        user = "skynet",
        password = "Password123",
        max_packet_size = 1024 * 1024,
        on_connect = function(db)
            db:query("set charset utf8")
        end
    })
    assert(db, "failed to connect to mysql")
end

-- 解析二进制请求
local function decode_auth_request(body)
    if not body or #body < 9 then  -- 至少需要 type(4) + length(4) + 内容(1)
        return nil, "Invalid request format: too short"
    end
    
    local auth_type = string.unpack("<i4", body, 1)
    local msg_len = string.unpack("<i4", body, 5)
    local message = string.sub(body, 9)
    
    -- 解析消息内容（格式：username|password）
    local username, password = string.match(message, "([^|]+)|([^|]+)")
    if not username or not password then
        return nil, "Invalid message format"
    end
    
    return {
        type = auth_type,
        username = username,
        password = password
    }
end

-- 编码二进制响应
local function encode_auth_response(code, msg, user_id, user_name)
    -- 构造消息内容
    local message
    if code == 200 and user_id then
        message = string.format("%s|%d|%s", msg, user_id, user_name)
    else
        message = msg
    end
    
    -- 按照 simplewebsocket 的格式打包
    return string.pack("<i4i4", code, #message) .. message
end

-- http返回消息
local function response(id, code, msg)
    local encoded = encode_auth_response(code, msg)
    local ok, err = httpd.write_response(sockethelper.writefunc(id), 200, encoded, {
        ["Content-Type"] = "application/x-sproto",
        ["Access-Control-Allow-Origin"] = "*",
        ["Access-Control-Allow-Methods"] = "POST, GET, OPTIONS",
        ["Access-Control-Allow-Headers"] = "Content-Type"
    })
    if not ok then
        skynet.tracelog("response", string.format("response error: fd = %d, %s", id, err))
    end
end

local function handle_login(id, params, agent_id)
    local username = params.username
    local password = params.password
    
    if not username or not password then
        return response(id, 400, "Missing username or password")
    end
    
    local sql = string.format("SELECT user_id, user_name FROM d_user WHERE user_name='%s' AND user_password='%s'", 
        username, password)
    local res = db:query(sql)
    
    if #res > 0 then
        local user_id = res[1].user_id
        local user_name = res[1].user_name
        
        skynet.tracelog("login", string.format("login_service已校验通过 user_id: %s", user_id))
        skynet.tracelog("login", string.format("当前agent_id: %s", agent_id))

        -- 获取用户管理服务地址
        local user_mgr_addr = tonumber(skynet.getenv("SKYNET_USER_MGR_ADDR"))
        assert(user_mgr_addr, "user_mgr_addr not found in environment")

        -- 先生成token
        local ok, token = pcall(skynet.call, user_mgr_addr, "lua", "generate_token", user_id)
        if not ok or not token then
            skynet.tracelog("login", string.format("generate_token error: %s", token))
            return response(id, 500, "Failed to generate token")
        end

        -- 添加新的连接到在线用户列表
        local add_ok = skynet.call(user_mgr_addr, "lua", "add_online_user", user_id, id, agent_id, token)
        if not add_ok then
            skynet.tracelog("login", string.format("add_online_user failed for user_id: %s", user_id))
            return response(id, 500, "Failed to add online user")
        end
        
        skynet.tracelog("login", string.format("Login successful - user_id: %s agent_id: %s token: %s", user_id, agent_id, token))
        -- 返回登录成功信息，包括 WebSocket 连接所需的信息
        response(id, 200, token)
    else
        response(id, 401, "Invalid username or password")
    end
end

local function handle_register(id, params)
    local username = params.username
    local password = params.password
    
    if not username or not password then
        return response(id, 400, "Missing username or password")
    end
    
    -- 检查用户名是否已存在
    local check_sql = string.format("SELECT user_id FROM d_user WHERE user_name='%s'", username)
    local res = db:query(check_sql)
    
    if #res > 0 then
        return response(id, 400, "Username already exists")
    end
    
    -- 插入新用户
    local insert_sql = string.format("INSERT INTO d_user (user_name, user_password) VALUES ('%s', '%s')", 
        username, password)
    local ok = db:query(insert_sql)
    
    if ok then
        response(id, 200, "Registration successful")
    else
        response(id, 500, "Registration failed")
    end
end

local function handle_request(id, req, agent_id)
    local path, query = req.path, req.query
    local method = req.method
    
    if method == "OPTIONS" then
        return response(id, 200, "OK")
    end
    
    -- 解析二进制请求
    local params, err = decode_auth_request(req.body)
    if not params then
        return response(id, 400, "Invalid request format: " .. (err or "unknown error"))
    end
    
    if params.type == 1 then
        handle_register(id, params)
    elseif params.type == 2 then
        handle_login(id, params, agent_id)
    else
        response(id, 404, "Not Found")
    end
end

local function handle_socket(id)
    socket.start(id)
    local ok, err = pcall(function()
        local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
        
        if code then
            if code ~= 200 then
                response(id, code, "error")
                return
            end
            local path, query = urllib.parse(url)
            
            local req = {
                path = path,
                query = query,
                method = method,
                header = header,
                body = body,
            }
            handle_request(id, req, skynet.self())
        else
            if err then
                skynet.tracelog("socket", string.format("invalid http request: %s", err))
            end
        end
    end)
    socket.close(id)
end

skynet.start(function()
    
    init_mysql()
    local port = 8080
    local id = socket.listen("0.0.0.0", port)
    skynet.tracelog("init", string.format("Login service listening on port %d", port))
    socket.start(id, function(id, addr)
        skynet.fork(handle_socket, id)
    end)
end) 