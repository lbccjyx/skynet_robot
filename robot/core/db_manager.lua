local skynet = require "skynet"
local mysql = require "skynet.db.mysql"

local DBManager = {}
DBManager.__index = DBManager

local instance = nil

function DBManager.getInstance()
    if not instance then
        instance = setmetatable({
            connection = nil,
            is_connecting = false,
            last_error = nil,
            retry_count = 0,
            max_retries = 3
        }, DBManager)
    end
    return instance
end

-- 初始化数据库连接
function DBManager:init()
    if self.connection then
        -- 如果已经有连接，先检查连接是否有效
        local ok = pcall(function()
            return self.connection:query("SELECT 1")
        end)
        if ok then
            return true
        end
        -- 连接无效，关闭它
        self.connection:disconnect()
        self.connection = nil
    end

    if self.is_connecting then
        return false, "Connection in progress"
    end

    self.is_connecting = true

    -- 从环境变量获取配置
    local db_config = {
        host = skynet.getenv("mysql_host") or "127.0.0.1",
        port = tonumber(skynet.getenv("mysql_port")) or 3306,
        database = skynet.getenv("mysql_database") or "skynet",
        user = skynet.getenv("mysql_user") or "root",
        password = skynet.getenv("mysql_password") or "your_password",
        max_packet_size = 1024 * 1024,
        auth_plugin = "mysql_native_password",
        on_connect = function(db)
            db:query("set charset utf8")
        end
    }

    -- 创建新连接
    local ok, db = pcall(mysql.connect, db_config)
    if not ok then
        self.last_error = db
        self.is_connecting = false
        skynet.error("Failed to connect to database:", db)
        return false, db
    end

    -- 设置认证插件
    local result = db:query("ALTER USER '" .. db_config.user .. "'@'localhost' IDENTIFIED WITH mysql_native_password BY '" .. db_config.password .. "'")
    if not result then
        self.last_error = "Failed to set authentication plugin"
        self.is_connecting = false
        skynet.error(self.last_error)
        return false, self.last_error
    end

    self.connection = db
    self.is_connecting = false
    self.retry_count = 0
    return true
end

-- 执行查询
function DBManager:query(sql, ...)
    if not self.connection then
        if self.retry_count >= self.max_retries then
            return false, "Max retry attempts reached"
        end
        
        self.retry_count = self.retry_count + 1
        local ok, err = self:init()
        if not ok then
            return false, err
        end
    end

    local formatted_sql = string.format(sql, ...)
    local ok, result = pcall(function()
        return self.connection:query(formatted_sql)
    end)

    if not ok then
        skynet.error("Database error:", result)
        -- 连接可能断开，下次查询时重试
        self.connection = nil
        return false, result
    end

    return true, result
end

-- 开始事务
function DBManager:begin()
    return self:query("START TRANSACTION")
end

-- 提交事务
function DBManager:commit()
    return self:query("COMMIT")
end

-- 回滚事务
function DBManager:rollback()
    return self:query("ROLLBACK")
end

-- 关闭连接
function DBManager:close()
    if self.connection then
        self.connection:disconnect()
        self.connection = nil
    end
end

return DBManager 