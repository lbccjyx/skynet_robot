// 服务器配置
export const SERVER_CONFIG = {
    // 主服务器地址
    HOST: '192.168.3.43',
    // 认证服务器端口
    AUTH_PORT: 8080,
    // WebSocket服务器端口
    WS_PORT: 9948,
    // 资源服务器端口
    ASSETS_PORT: 8000,
    
    // 获取完整的认证服务器URL
    getAuthUrl: function() {
        return `http://${this.HOST}:${this.AUTH_PORT}`;
    },
    
    // 获取WebSocket服务器URL
    getWsUrl: function() {
        return `ws://${this.HOST}:${this.WS_PORT}`;
    },
    
    // 获取资源服务器URL
    getAssetsUrl: function() {
        return `http://${this.HOST}:${this.ASSETS_PORT}`;
    }
};
