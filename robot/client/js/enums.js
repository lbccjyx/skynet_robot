// 服务端客户端交互消息类型枚举
export const MSG_TYPE = {
    AUTH: 1,
    AUTH_RESPONSE: 2,
    WS_MESSAGE: 3,
    KICK_OUT: 4,
    NORMAL_POS: 5,
    ROBOT_POS: 6,
    HEARTBEAT: 7
};

// 建筑类型枚举
export const STRUCT_TYPE = {
    CHENGQIANG: 1,     // 城墙
    GUANFU: 2,         // 官府
};

// 物品类型枚举
export const ITEM_TYPE = {
    GOLD: 1,           // 金币
    WOOD: 2,           // 木材
    STONE: 3,          // 石头
    IRON: 4,           // 铁矿
};