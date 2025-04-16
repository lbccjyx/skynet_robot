// 服务端客户端交互消息类型枚举
export const NORMAL_MSG_TYPE = {
    AUTH_RESPONSE: 1,
    WS_MESSAGE: 2,
    KICK_OUT: 3,
    ROBOT_POS: 4,
    HEARTBEAT: 5
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

// 协议类型枚举
export const PROTOCOL = {
    LOGIN: 'PROTOCOL_LOGIN',                    // 101
    NORMAL_RESP: 'PROTOCOL_NORMAL_RESP',        // 102
    NORMAL_REQ: 'PROTOCOL_NORMAL_REQ',          // 103
    NORMAL_POS_C_TO_S: 'PROTOCOL_NORMAL_POS_C_TO_S',  // 104
    NORMAL_POS_SEND: 'PROTOCOL_NORMAL_POS_SEND',        // 105
    NORMAL_STR_RESP: 'PROTOCOL_NORMAL_STR_RESP'
};