// 编码认证消息
function encodeSprotoAuth(type, username, password) {
    const message = `${username}|${password}`;
    const messageBytes = new TextEncoder().encode(message);
    
    // 计算总长度：type(4) + length(4) + message
    const buffer = new ArrayBuffer(8 + messageBytes.length);
    const view = new DataView(buffer);
    
    // 写入类型
    view.setInt32(0, type, true);
    // 写入消息长度
    view.setInt32(4, messageBytes.length, true);
    // 写入消息内容
    new Uint8Array(buffer, 8).set(messageBytes);
    
    return buffer;
}

// 解码认证响应
function decodeSprotoAuthResponse(buffer) {
    const view = new DataView(buffer);
    const textDecoder = new TextDecoder();
    
    // 读取状态码
    const code = view.getInt32(0, true);
    // 读取消息长度
    const msgLength = view.getInt32(4, true);
    // 读取消息内容
    const messageBytes = new Uint8Array(buffer, 8, msgLength);
    const message = textDecoder.decode(messageBytes);
    
    return { code, message };
}

// 编码WebSocket消息
function encodeMessage(type, message) {
    const messageBytes = new TextEncoder().encode(message);
    const buffer = new ArrayBuffer(8 + messageBytes.length);
    const view = new DataView(buffer);
    
    // 写入消息类型
    view.setInt32(0, type, true);
    // 写入消息长度
    view.setInt32(4, messageBytes.length, true);
    // 写入消息内容
    new Uint8Array(buffer, 8).set(messageBytes);
    
    return buffer;
}

// 解码WebSocket消息
function decodeMessage(buffer) {
    const view = new DataView(buffer);
    const textDecoder = new TextDecoder();
    
    // 读取消息类型
    const type = view.getInt32(0, true);
    // 读取消息长度
    const messageLength = view.getInt32(4, true);
    // 读取消息内容
    const messageBytes = new Uint8Array(buffer, 8, messageLength);
    const message = textDecoder.decode(messageBytes);
    
    return { type, message };
}

// 编码NormalPos消息
function encodeNormalPos(normalPos) {
    const message = JSON.stringify(normalPos);
    const messageBytes = new TextEncoder().encode(message);
    
    // 计算总长度：type(4) + length(4) + message
    const buffer = new ArrayBuffer(8 + messageBytes.length);
    const view = new DataView(buffer);
    
    // 写入类型
    view.setInt32(0, 1, true);  // NormalPos消息类型为1
    // 写入消息长度
    view.setInt32(4, messageBytes.length, true);
    // 写入消息内容
    new Uint8Array(buffer, 8).set(messageBytes);
    
    return buffer;
}

// 解码RobotPos消息
function decodeRobotPos(buffer) {
    const view = new DataView(buffer);
    const textDecoder = new TextDecoder();
    
    // 读取消息类型
    const type = view.getInt32(0, true);
    // 读取消息长度
    const msgLength = view.getInt32(4, true);
    // 读取消息内容
    const messageBytes = new Uint8Array(buffer, 8, msgLength);
    const message = textDecoder.decode(messageBytes);
    
    return { type, message };
}

// 导出函数
window.encodeSprotoAuth = encodeSprotoAuth;
window.decodeSprotoAuthResponse = decodeSprotoAuthResponse;
window.encodeMessage = encodeMessage;
window.decodeMessage = decodeMessage;
window.encodeNormalPos = encodeNormalPos;
window.decodeRobotPos = decodeRobotPos; 