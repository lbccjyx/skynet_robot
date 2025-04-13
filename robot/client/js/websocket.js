import { NORMAL_MSG_TYPE,PROTOCOL } from './enums.js';
import { appendMessage } from './ui.js';
import { getSproto, initSproto } from './sproto-helper.js';

let sprotoInstance = null;
let ws = null;
let currentWsInfo = null;

// 处理服务器消息
function handleNormalResponse(message) {
    switch (message.type) {
        case NORMAL_MSG_TYPE.AUTH:
            handleAuthResponse(message);
            break;
        case NORMAL_MSG_TYPE.KICK_OUT:
            handleKickOut(message);
            break;
        default:
            appendMessage('服务器', `未知类型消息: ${message.type}, 内容: ${message.message}`);
    }
}

// 处理认证响应
function handleAuthResponse(message) {
    const response = JSON.parse(message.message);
    if (response.code === 200) {
        appendMessage('系统', '登录成功');
        // 保存token
        localStorage.setItem('token', response.msg);
    } else {
        appendMessage('系统', `登录失败: ${response.msg}`);
    }
}

// 处理踢出消息
function handleKickOut(message) {
    const kickOut = JSON.parse(message.message);
    appendMessage('系统', `您已被踢出: ${kickOut.reason}`);
    ws.close();
    logout();
}

// 处理机器人位置消息
function handleRobotPos(message) {
    try {
        const robotPos = JSON.parse(message.message);
        // 更新游戏中的机器人位置
        if (window.game && window.game.scene && window.game.scene.scenes[0]) {
            const gameScene = window.game.scene.scenes[0];
            gameScene.updateRobotPosition(robotPos);
        }
    } catch (err) {
        console.error("Failed to process RobotPos message:", err);
    }
}

// 发送所有的协议消息接口
/**
 * 发送 protobuf 消息到服务端
 * @param {string} protocolName - 协议名称（如 "PROTOCOL_NORMAL_REQ"）
 * @param {object} message - 消息对象，如 {type: 5, message: "guanfu"}
 */
function SendProtoMessage(protocolName, message) {
    if (!ws || ws.readyState !== WebSocket.OPEN) {
        console.error("WebSocket未连接");
        throw new Error("WebSocket未连接");
    }

    try {
        if (!sprotoInstance) {
            sprotoInstance = getSproto();
            if(!sprotoInstance) {                
                console.error("Sproto未初始化");
                throw new Error('Sproto未初始化');
            }
        }

        console.log('开始编码消息:', {
            protocolName,
            message
        });

        // 1. 根据协议名称查找协议定义
        const protocol = sprotoInstance.protocol(protocolName);
        if (!protocol) {
            console.error(`未知的协议名称: ${protocolName}`);
            throw new Error(`未知的协议名称: ${protocolName}`);
        }

        // 2. 编码消息
        const encodedMessage = sprotoInstance.encode(protocolName, message);
        if (!encodedMessage) {
            console.error('消息编码失败:', message);
            throw new Error('消息编码失败');
        }

        if (!encodedMessage.buf || !encodedMessage.sz) {
            console.error('编码结果无效:', encodedMessage);
            throw new Error('编码结果无效');
        }

        console.log('消息编码成功:', {
            protocolTag: protocol.id,
            messageSize: encodedMessage.sz,
            message: encodedMessage.buf
        });

        // 3. 构建二进制消息头 (8字节)
        const header = new ArrayBuffer(8);
        const headerView = new DataView(header);
        headerView.setInt32(0, protocol.id, true);   // 4字节 proto_id (小端序)
        headerView.setInt32(4, encodedMessage.sz, true); // 4字节 消息长度 (小端序)

        // 4. 合并头和消息体
        const fullMessage = new Uint8Array(8 + encodedMessage.sz);
        fullMessage.set(new Uint8Array(header), 0);
        
        // 直接使用编码后的数字数组
        fullMessage.set(encodedMessage.buf, 8);

        console.log('准备发送二进制数据:', {
            totalSize: fullMessage.length,
            headerSize: 8,
            bodySize: encodedMessage.sz,
            messageBytes: Array.from(fullMessage.slice(8))  // 打印消息内容用于调试
        });

        // 5. 发送二进制消息
        ws.send(fullMessage.buffer);
        console.log('消息发送成功');

    } catch (err) {
        console.error("发送proto消息失败:", err);
        throw err;
    }
}

// 处理所有的WebSocket消息接口
function handleWsMessage(protoId, messageBody) {
    // 解码消息
    const protocol = sprotoInstance.protocol(protoId);
    if (!protocol) {
        throw new Error(`Protocol not found: ${protoId}`);
    }

    // 解码 response（即 WsMessage 结构）
    const result = sprotoInstance.decode(protocol.response, messageBody);
    if (!result) {
        throw new Error("Failed to decode message");
    }

    switch (sprotoInstance.getProtocolName(protoId)) {
        case PROTOCOL.NORMAL_RESP:
            console.log("Type:", result.type); // 访问 type 字段
            console.log("Message:", result.message); // 访问 message 字段
            handleNormalResponse(result);
            break;
        case PROTOCOL.AUTH_RESP:
            handleAuthResponse(result);
            break;
        case PROTOCOL.KICK_OUT:
            handleKickOut(result);
            break;
        case PROTOCOL.ROBOT_POS:
            handleRobotPos(result);
            break;
        default:
            console.log("Unknown protocol:", protoId);
            break;
    }
}

// 与服务端的连接
function ConnectWebSocket(info) {
    if (ws) {
        ws.close();
    }
    
    currentWsInfo = info;  // 保存连接信息
    
    // 添加token到URL
    const wsUrl = `${info.ws_host}?token=${info.token}`;
    ws = new WebSocket(wsUrl);
    ws.binaryType = "arraybuffer";  // 确保接收二进制数据
    
    ws.onopen = function() {
        console.log("WebSocket连接已建立");
        appendMessage("系统", "WebSocket连接已建立");
    };
    
    ws.onmessage = function(event) {
        try {
            if (event.data instanceof ArrayBuffer) {
                const data = new Uint8Array(event.data);
                const view = new DataView(event.data);
    
                // 解析协议ID和消息长度（小端序）
                const protoId = view.getInt32(0, true);
                const messageLength = view.getInt32(4, true);
    
                // 提取消息体
                const messageBody = data.slice(8, 8 + messageLength);
    
                // 解码
                handleWsMessage(protoId, messageBody);

            } else {
                console.log("Text message:", event.data);
            }
        } catch (err) {
            console.error("Decode error:", err);
        }
    };
    
    ws.onclose = function() {
        appendMessage('系统', '连接已关闭');
        ws = null;
        
        // 如果不是主动登出，则尝试重连
        if (currentWsInfo) {
            appendMessage('系统', '尝试重新连接...');
            setTimeout(() => ConnectWebSocket(currentWsInfo), 3000);
        }
    };
    
    ws.onerror = function(error) {
        appendMessage('系统', '连接发生错误');
        console.error('WebSocket error:', error);
    };
}

// 导出需要的函数和变量
export { ConnectWebSocket, SendProtoMessage };
