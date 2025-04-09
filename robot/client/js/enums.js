// 消息类型枚举
const MSG_TYPE = {
    ECHO: 1,           // 回显消息
    ROBOT_CTRL: 2,     // 机器人控制响应
    ROBOT_MSG: 3,      // 机器人消息
    KICK_OUT: 4,       // 踢出消息
    BUILD_INFO: 5,     // 建筑信息
};

// 建筑类型枚举
const STRUCT_TYPE = {
    CHENGQIANG: 1,     // 城墙
    GUANFU: 2,         // 官府
};

// 物品类型枚举
const ITEM_TYPE = {
    GOLD: 1,           // 金币
    WOOD: 2,           // 木材
    STONE: 3,          // 石头
    IRON: 4,           // 铁矿
};

// 导出到全局作用域
window.MSG_TYPE = MSG_TYPE;
window.STRUCT_TYPE = STRUCT_TYPE;
window.ITEM_TYPE = ITEM_TYPE; 