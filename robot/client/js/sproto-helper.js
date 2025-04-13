import { Sproto } from './sproto.js';

let sprotoInstance = null;

export function initSproto(sprotoDesc) {
    try {
        // 首先解码 base64 字符串获取原始协议内容
        const decodedContent = atob(sprotoDesc);
        //console.log('Decoded sproto content:', decodedContent);
        
        // 使用新的解析方式创建实例
        sprotoInstance = Sproto.new(decodedContent);
        
        if (!sprotoInstance) {
            throw new Error('Failed to create Sproto instance');
        }
        
        console.log('Sproto initialized successfully');
        return sprotoInstance;
    } catch (error) {
        console.error('Failed to initialize Sproto:', error);
        throw error;
    }
}

export function getSproto() {
    if (!sprotoInstance) {
        throw new Error('Sproto not initialized');
    }
    return sprotoInstance;
}

// 用于测试协议解析
export function testSprotoProtocol(name) {
    const proto = sprotoInstance?.protocol(name);
    console.log(`Protocol ${name}:`, proto);
    return proto;
}