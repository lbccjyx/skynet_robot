local sproto = require "sproto"
local sprotoparser = require "sprotoparser"

local ProtoLoader = {}

function ProtoLoader:new()
    local o = {
        m_proto_data = nil,     -- 原始协议数据
        m_sproto_schema = nil,  -- 解析后的schema
        m_sproto = nil,         -- sproto实例
        m_loaded = false        -- 加载标志
    }
    setmetatable(o, {__index = self})
    return o
end

-- 核心加载方法（内部使用）
function ProtoLoader:_load()
    if self.m_loaded then return end
    
    -- 1. 读取协议文件
    local sp_file, err = io.open("robot/proto/ws.sproto", "r")
    if not sp_file then
        error(string.format("打开协议文件失败: %s", err))
    end
    self.m_proto_data = sp_file:read("*a")
    sp_file:close()

    -- 2. 解析schema
    self.m_sproto_schema = sprotoparser.parse(self.m_proto_data)
    if not self.m_sproto_schema then
        error("解析协议文件失败")
    end

    -- 3. 创建sproto实例
    self.m_sproto = sproto.new(self.m_sproto_schema)
    if not self.m_sproto then
        error("创建sproto实例失败")
    end

    self.m_loaded = true
end

-- 获取原始协议数据
function ProtoLoader:get_proto_data()
    if not self.m_loaded then
        self:_load()
    end
    return self.m_proto_data
end

-- 获取sproto实例（带懒加载）
function ProtoLoader:get_sproto()
    if not self.m_loaded then
        self:_load()
    end
    return self.m_sproto
end

-- 获取schema（带懒加载）
function ProtoLoader:get_schema()
    if not self.m_loaded then
        self:_load()
    end
    return self.m_sproto_schema
end

-- 重新加载协议（强制刷新）
function ProtoLoader:reload()
    self.m_loaded = false
    self:_load()
end

return ProtoLoader