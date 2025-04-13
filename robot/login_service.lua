local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local ProtoLoader = require "proto_loader"

local json = require "json"
local base64 = require "base64"
local DBManager = require "core.db_manager"

local db
local host
local sproto_obj
local sproto_content  -- 保存原始的sproto内容


local function load_proto()
    local loader = ProtoLoader:new()
    local ok, obj = pcall(loader.get_sproto, loader)
    if not ok then
        skynet.error("Failed to create sproto object:", obj)
        return false
    end
    
    local ok2, content = pcall(loader.get_proto_data, loader)
    if not ok2 then
        skynet.error("Failed to get proto data:", content)
        return false
    end
    
    -- 正确设置模块级变量（去掉local）
    sproto_obj = obj
    sproto_content = content
    host = sproto_obj:host "package"
    
    return true
end

skynet.init(function()
    -- 如果是多线程环境，建议这样使用：
    if host then return true end  -- 已经初始化

    load_proto()
    if not host then
        skynet.error("Failed to create sproto host")
        return
    end
    
    skynet.error("Sproto initialized successfully")
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

-- 解析JSON请求体
local function parse_json_body(body)
    if not body or body == "" then
        return nil, "Empty request body"
    end
    local ok, data = pcall(json.decode, body)
    if not ok then
        return nil, "Invalid JSON format"
    end
    return data
end

-- HTTP JSON响应
local function json_response(id, code, data)
    skynet.tracelog("response", string.format("准备发送响应 - fd: %d, code: %d, data: %s", id, code, json.encode(data)))
    local encoded = json.encode(data)
    local ok, err = httpd.write_response(
        sockethelper.writefunc(id),
        code,
        encoded,
        {
            ["Content-Type"] = "application/json",
            ["Access-Control-Allow-Origin"] = "*",
            ["Access-Control-Allow-Methods"] = "POST, GET, OPTIONS",
            ["Access-Control-Allow-Headers"] = "Content-Type"
        }
    )
    if not ok then
        skynet.tracelog("response", string.format("response error: fd = %d, %s", id, err))
    else
        skynet.tracelog("response", string.format("响应发送成功 - fd: %d", id))
    end
    return ok
end

local function handle_login(id, params, agent_id)
    skynet.tracelog("login", string.format("[1] 开始处理登录请求 - id: %s, agent_id: %s", id, agent_id))
    
    local username = params.username
    local password = params.password
    skynet.tracelog("login", string.format("[2] 获取登录参数 - username: %s", username or "nil"))
    
    if not username or not password then
        skynet.tracelog("login", "[3] 用户名或密码为空")
        return json_response(id, 400, { success = false, message = "Missing username or password" })
    end
    
    skynet.tracelog("login", "[4] 准备查询数据库")
    local sql = string.format("SELECT user_id, user_name FROM d_user WHERE user_name='%s' AND user_password='%s'", 
        username, password)
    skynet.tracelog("login", string.format("[5] SQL语句: %s", sql))
    
    local res = db:query(sql)
    skynet.tracelog("login", string.format("[6] 数据库查询结果数量: %d", #res))
    
    if #res > 0 then
        local user_id = res[1].user_id
        local user_name = res[1].user_name
        skynet.tracelog("login", string.format("[7] 用户验证通过 - user_id: %s, user_name: %s", user_id, user_name))

        -- 获取用户管理服务地址
        skynet.tracelog("login", "[8] 获取用户管理服务地址")
        local user_mgr_addr = tonumber(skynet.getenv("SKYNET_USER_MGR_ADDR"))
        if not user_mgr_addr then
            skynet.tracelog("login", "[9] 错误：未找到用户管理服务地址")
            return json_response(id, 500, { success = false, message = "Internal server error" })
        end
        skynet.tracelog("login", string.format("[10] 用户管理服务地址: %s", user_mgr_addr))

        -- 生成token
        skynet.tracelog("login", "[11] 开始生成token")
        local ok, token = pcall(skynet.call, user_mgr_addr, "lua", "generate_token", user_id)
        if not ok or not token then
            skynet.tracelog("login", string.format("[12] token生成失败: %s", token))
            return json_response(id, 500, { success = false, message = "Failed to generate token" })
        end
        skynet.tracelog("login", string.format("[13] token生成成功: %s", token))

        -- 添加在线用户
        skynet.tracelog("login", "[14] 开始添加在线用户")
        local add_ok = skynet.call(user_mgr_addr, "lua", "add_online_user", user_id, id, agent_id, token)
        if not add_ok then
            skynet.tracelog("login", string.format("[15] 添加在线用户失败 - user_id: %s", user_id))
            return json_response(id, 500, { success = false, message = "Failed to add online user" })
        end
        skynet.tracelog("login", "[16] 添加在线用户成功")
        
        -- 获取sproto协议描述并Base64编码
        skynet.tracelog("login", "[17] 开始获取sproto协议描述")
        -- 直接使用原始的sproto内容
        if not load_proto() then           
            skynet.tracelog("login", "[17.1] 错误：sproto内容为空")
            return json_response(id, 500, { success = false, message = "Sproto content is empty" })
        end
        
        local ok2, sproto_desc = pcall(base64.encode, sproto_content)
        if not ok2 then
            skynet.tracelog("login", string.format("[17.2] base64编码失败: %s", sproto_desc))
            return json_response(id, 500, { success = false, message = "Failed to encode sproto" })
        end
        skynet.tracelog("login", string.format("[18] sproto协议描述长度: %d", #sproto_desc))
        
        skynet.tracelog("login", "[19] 准备发送成功响应")
        -- 返回JSON响应，包含token和sproto_desc
        json_response(id, 200, {
            success = true,
            message = "Login successful",
            token = token,
            user_id = user_id,
            user_name = user_name,
            sproto_version = "1.0.0",
            sproto_desc = sproto_desc
        })
        skynet.tracelog("login", "[20] 登录流程完成")
    else
        skynet.tracelog("login", "[21] 用户名或密码错误")
        json_response(id, 401, { success = false, message = "Invalid username or password" })
    end
end

local function handle_register(id, params)
    local username = params.username
    local password = params.password
    
    if not username or not password then
        return json_response(id, 400, { success = false, message = "Missing username or password" })
    end
    
    -- 检查用户名是否已存在
    local check_sql = string.format("SELECT user_id FROM d_user WHERE user_name='%s'", username)
    local res = db:query(check_sql)
    
    if #res > 0 then
        return json_response(id, 400, { success = false, message = "Username already exists" })
    end
    
    -- 插入新用户
    local insert_sql = string.format("INSERT INTO d_user (user_name, user_password) VALUES ('%s', '%s')", 
        username, password)
    local ok = db:query(insert_sql)
    
    if ok then
        json_response(id, 200, { success = true, message = "Registration successful" })
    else
        json_response(id, 500, { success = false, message = "Registration failed" })
    end
end

local function handle_request(id, req, agent_id)
    local path, query = req.path, req.query
    local method = req.method
    
    if method == "OPTIONS" then
        return json_response(id, 200, { success = true })
    end
    
    -- 解析JSON请求体
    local params, err = parse_json_body(req.body)
    if not params then
        return json_response(id, 400, { success = false, message = "Invalid request: " .. (err or "unknown error") })
    end
    
    if path == "/register" then
        handle_register(id, params)
    elseif path == "/login" then
        handle_login(id, params, agent_id)
    else
        json_response(id, 404, { success = false, message = "Not Found" })
    end
end

local function handle_socket(id)
    socket.start(id)
    local ok, err = pcall(function()
        local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
        
        if code then
            if code ~= 200 then
                json_response(id, code, { success = false, message = "HTTP error" })
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
            
            -- 确保在处理请求时捕获所有可能的错误
            local ok, err = pcall(handle_request, id, req, skynet.self())
            if not ok then
                skynet.tracelog("error", string.format("处理请求失败: %s", err))
                json_response(id, 500, { success = false, message = "Internal server error" })
            end
        else
            if err then
                skynet.tracelog("socket", string.format("invalid http request: %s", err))
                json_response(id, 400, { success = false, message = "Invalid HTTP request" })
            end
        end
    end)
    
    if not ok then
        skynet.tracelog("error", string.format("Socket处理异常: %s", err))
        pcall(json_response, id, 500, { success = false, message = "Internal server error" })
    end
    
    -- 确保在所有响应都发送完毕后再关闭socket
    skynet.sleep(100)  -- 给响应一些发送的时间
    socket.close(id)
end

skynet.start(function()
    init_mysql()
    if not load_proto() then
        skynet.error("Critical error: failed to initialize sproto")
        skynet.exit()
    end
    local port = 8080
    local id = socket.listen("0.0.0.0", port)
    skynet.tracelog("init", string.format("Login service listening on port %d", port))
    socket.start(id, function(id, addr)
        skynet.fork(handle_socket, id)
    end)
end)