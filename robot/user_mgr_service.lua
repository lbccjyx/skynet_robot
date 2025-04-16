local skynet = require "skynet"
local CUser = require "user"

local CMD = {}
local online_users = {}  -- 存储在线用户的CUser实例
local user_tokens = {}   -- 存储用户token

function CMD.add_online_user(user_id, socket_id, agent_handle, token)
    -- skynet.tracelog("dispatch", "user_mgr_service 收到命令: add_online_user")
    
    -- 验证token
    if not token then
        skynet.tracelog("add_online_user", "No token provided")
        return false
    end

    -- 检查token是否匹配
    if not user_tokens[token] or user_tokens[token] ~= user_id then
        -- skynet.tracelog("add_online_user", string.format("Invalid token: %s for user: %s", token, user_id))
        return false
    end
    
    -- 如果用户已在线，处理旧连接
    if online_users[user_id] then
        local old_user = online_users[user_id]
        if old_user.socket_id and old_user.agent_handle then
            -- 查找并清理旧token
            for old_token, uid in pairs(user_tokens) do
                if uid == user_id and old_token ~= token then
                    -- 发送踢出消息给旧连接
                    skynet.tracelog("add_online_user", string.format("Kicking out old connection for user_id: %s, socket_id: %s", user_id, old_user.socket_id))
                    pcall(skynet.call, old_user.agent_handle, "lua", "send_message", old_user.socket_id,  "WsMessage",{
                        type = 4,
                        message = "Account logged in elsewhere"
                    })
                    -- 清理旧token
                    user_tokens[old_token] = nil
                    break
                end
            end
        end
        -- 只更新连接相关的信息，保留其他用户数据
        old_user.socket_id = socket_id
        old_user.agent_handle = agent_handle
    else
        -- 如果是新用户，创建新的用户实例
        local user = CUser.new(user_id, socket_id, agent_handle)
        online_users[user_id] = user
    end
    
    return true
end

function CMD.get_user(user_id)
    return online_users[user_id]
end

function CMD.generate_token(user_id)
    local token = string.format("token_%d_%d", user_id, os.time())
    user_tokens[token] = user_id
    return token
end

function CMD.verify_token(token)
    return user_tokens[token]
end

-- 新增：WebSocket验证成功后调用此函数清理token
function CMD.clear_token(token)
    if token then
        user_tokens[token] = nil
        return true
    end
    return false
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("Unknown command: ", cmd)
        end
    end)
    
    skynet.tracelog("init", string.format("%d user_mgr_service started", skynet.self()))
end) 