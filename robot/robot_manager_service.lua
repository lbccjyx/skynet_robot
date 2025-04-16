local skynet = require "skynet"
local RobotManager = require "robot_manager"

local robot_managers = {}  -- 存储所有玩家的机器人管理器，key是user_id

local CMD = {}

-- 初始化玩家的机器人管理器
function CMD.init_manager(user_id, agent_handle, socket_id, host)
    -- 如果已存在，先停止并清理旧的
    if robot_managers[user_id] then
        robot_managers[user_id]:stop_all_robots()
    end
    
    -- 创建新的管理器
    local manager = RobotManager.new()
    local ok = manager:init(user_id, agent_handle, socket_id, host)
    if not ok then
        skynet.error("Failed to initialize robot manager for user: ", user_id)
        return false
    end
    
    robot_managers[user_id] = manager
    return true
end

-- 获取玩家的机器人管理器
function CMD.get_manager(user_id)
    return robot_managers[user_id]
end

-- 创建机器人
function CMD.create_robots(user_id, count)
    local manager = robot_managers[user_id]
    if not manager then
        skynet.error("No robot manager found for user: ", user_id)
        return 0
    end
    
    local start_id = manager:get_robot_count() + 1
    local created_count = 0
    
    for i = 1, count do
        if manager:create_robot(start_id + i - 1) then
            created_count = created_count + 1
        end
    end
    
    return created_count
end

-- 停止并清理玩家的所有机器人
function CMD.cleanup_user(user_id)
    local manager = robot_managers[user_id]
    if manager then
        manager:stop_all_robots()
        robot_managers[user_id] = nil
    end
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
    
end) 