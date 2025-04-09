local skynet = require "skynet"
local DBManager = require "core.db_manager"
local sharedata = require "skynet.sharedata"

local ConfigManager = {}
ConfigManager.__index = ConfigManager

local instance = nil

-- 配置表结构定义
-- 格式: {表名 = {主键字段名, [二级键字段名, 三级键字段名, ...]}}
-- 或者: {表名 = {{索引字段1, 索引字段2, ...}, {主键字段名, [二级键字段名, 三级键字段名, ...]}}
local config_structure = {
    ["s_struct"] = {
        -- 通过struct_id索引
        {"struct_id"},
        -- 通过str_name索引
        {"str_name"}
    },
    ["s_struct_upgrade"] = {"struct_id", "lev"},
    ["s_item"] = {"id"}
}

-- 获取单例实例
function ConfigManager.getInstance()
    if not instance then
        instance = setmetatable({}, ConfigManager)
    end
    return instance
end

-- 初始化配置管理器
function ConfigManager:init()
    -- 确保数据库连接已初始化
    local db = DBManager.getInstance()
    local ok, err = db:init()
    if not ok then
        skynet.error("Failed to initialize database connection:", err)
        return false, err
    end
    
    -- 加载所有配置表
    self:loadAllConfigs()
    return true
end

-- 加载所有配置表
function ConfigManager:loadAllConfigs()
    local db = DBManager.getInstance()
    local config_cache = {}
    
    -- 遍历配置表结构定义，加载所有配置表
    for table_name, structure in pairs(config_structure) do
        print(string.format("Loading config table:%s", table_name))
        local ok, result = db:query("SELECT * FROM " .. table_name)
        if ok then
            print(string.format("Query success, result count:%d", #result))
            config_cache[table_name] = {}
            
            -- 处理结果
            for _, row in ipairs(result) do
                -- 检查结构类型
                if type(structure[1]) == "table" then
                    -- 多索引结构
                    for _, index_fields in ipairs(structure) do
                        local first_field = index_fields[1]
                        
                        -- 创建索引目录
                        if not config_cache[table_name][first_field] then
                            config_cache[table_name][first_field] = {}
                        end
                        
                        -- 存储数据
                        if row[first_field] then
                            print(string.format("table_name:%s first_field:%s row[first_field]:%s", 
                                table_name, first_field, row[first_field]))
                            config_cache[table_name][first_field][row[first_field]] = row
                        end
                    end
                else
                    -- 单索引结构
                    local current = config_cache[table_name]
                    
                    -- 遍历所有键，构建嵌套结构
                    for i, key in ipairs(structure) do
                        local value = row[key]
                        
                        -- 如果是最后一个键，直接存储整行数据
                        if i == #structure then
                            current[value] = row
                        else
                            -- 否则创建下一级嵌套
                            if not current[value] then
                                current[value] = {}
                            end
                            current = current[value]
                        end
                    end
                end
            end
        else
            skynet.error("Failed to load config table: " .. table_name)
        end
    end
    
    -- 将配置数据存储到sharedata中
    sharedata.new("config_cache", config_cache)
    
    skynet.error("Config tables loaded successfully")
end

-- 重新加载所有配置
function ConfigManager:reloadAllConfigs()
    self:loadAllConfigs()
end

-- 获取配置（支持多级键）
function ConfigManager:getConfig(table_name, ...)
    local config_cache = sharedata.query("config_cache")
    if not config_cache[table_name] then
        return nil
    end
    
    local result = config_cache[table_name]
    local keys = {...}
    
    for i, key in ipairs(keys) do
        if not result then
            return nil
        end
        result = result[key]
    end
    
    return result
end

-- 通过指定索引字段获取配置
function ConfigManager:getConfigByIndex(table_name, index_field, index_value)
    print("**********ConfigManager:getConfigByIndex**********")
    local config_cache = sharedata.query("config_cache")
    if not config_cache then
        print("config_cache is nil")
        return nil
    end
    
    if not config_cache[table_name] then
        print("config_cache[table_name] is nil")
        return nil
    end
    
    if not config_cache[table_name][index_field] then
        print("config_cache[table_name][index_field] is nil")
        return nil
    end
    
    local result = config_cache[table_name][index_field][index_value]
    if not result then
        print("config_cache[table_name][index_field][index_value] is nil")
    end
    
    return result
end

-- 全局访问函数
function ConfigManager.GetCfg(table_name, ...)
    return ConfigManager.getInstance():getConfig(table_name, ...)
end

-- 通过指定索引字段获取配置的全局函数
function ConfigManager.GetCfgByIndex(table_name, index_field, index_value)
    return ConfigManager.getInstance():getConfigByIndex(table_name, index_field, index_value)
end

-- 为了向后兼容，也添加一个全局函数
function GetCfg(table_name, ...)
    return ConfigManager.GetCfg(table_name, ...)
end

-- 通过指定索引字段获取配置的全局函数
function GetCfgByIndex(table_name, index_field, index_value)
    return ConfigManager.GetCfgByIndex(table_name, index_field, index_value)
end

-- 将GetCfg函数添加到全局环境中
_G.GetCfg = GetCfg
_G.GetCfgByIndex = GetCfgByIndex

return ConfigManager 