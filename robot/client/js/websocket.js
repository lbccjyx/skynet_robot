import { NORMAL_MSG_TYPE,PROTOCOL } from './enums.js';
import { appendMessage } from './ui.js';
import { getSproto, initSproto } from './sproto-helper.js';
import { Sproto } from './sproto.js';

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

// 自己实现 sproto_protoquery_name 函数
function sproto_protoquery_name(name, sproto) {
    if (!sproto || !sproto.proto) return null;
    
    for (let i = 0; i < sproto.protocol_n; i++) {
        if (sproto.proto[i].name === name) {
            return sproto.proto[i];
        }
    }
    return null;
}


// 自己实现 sproto_protoname 函数
function sproto_protoname(proto) {
    if (!sprotoInstance || !sprotoInstance.proto) return null;
    
    for (let i = 0; i < sprotoInstance.protocol_n; i++) {
        if (sprotoInstance.proto[i].tag === proto) {
            return sprotoInstance.proto[i].name;
        }
    }
    return null;
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

        console.log('准备发送消息:', {
            protocol: protocolName,
            ...message
        });

        // 1. 根据协议名称查找协议定义
        const protocol = sproto_protoquery_name(protocolName, sprotoInstance);
        if (!protocol) {
            console.error(`未知的协议名称: ${protocolName}`);
            throw new Error(`未知的协议名称: ${protocolName}`);
        }

        // 确保协议有请求类型定义
        if (!protocol.p || !protocol.p[0]) {
            console.error(`协议 ${protocolName} 没有请求类型定义`);
            throw new Error(`协议 ${protocolName} 没有请求类型定义`);
        }
        // 打印调试信息
        console.log('找到协议:', {
            name: protocol.p[0].name,
            tag: protocol.tag,
            requestType: protocol.p[0].name
        });

        // 2. 编码消息
        const encodedMessage = sprotoInstance.encode( protocol.p[0].name, message);        if (!encodedMessage) {
            console.error('消息编码失败:', message);
            throw new Error('消息编码失败');
        }

        if (!encodedMessage.buf || !encodedMessage.sz) {
            console.error('编码结果无效:', encodedMessage);
            throw new Error('编码结果无效');
        }

        // 确保所有字节值都是正数且在0-255范围内
        const normalizedBuffer = encodedMessage.buf.map(byte => {
            // 如果是负数，转换为无符号值
            return byte < 0 ? byte + 256 : byte;
        });

        console.log('消息编码成功:', {
            protocolTag: protocol.tag,
            messageSize: encodedMessage.sz,
            message: normalizedBuffer
        });

        // 3. 构建二进制消息头 (8字节)
        const header = new ArrayBuffer(8);
        const headerView = new DataView(header);
        headerView.setInt32(0, protocol.tag, true);   // 4字节 proto_id (小端序)
        headerView.setInt32(4, encodedMessage.sz, true); // 4字节 消息长度 (小端序)

        // 4. 合并头和消息体
        const fullMessage = new Uint8Array(8 + encodedMessage.sz);
        fullMessage.set(new Uint8Array(header), 0);
        
        // 使用修正后的字节数组
        for (let i = 0; i < normalizedBuffer.length; i++) {
            fullMessage[8 + i] = normalizedBuffer[i];
        }

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
    const protocol = findProtocolById(sprotoInstance, protoId);
    if (!protocol) {
        throw new Error(`Protocol not found: ${protoId}`);
    }

    // 解码 response（即 WsMessage 结构）
    const result = sprotoInstance.decode(protocol.p[0].response, messageBody);
    if (!result) {
        throw new Error("Failed to decode message");
    }

    const protocolName =  sproto_protoname(protoId);
    switch (protocolName) {
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
// 添加辅助函数：根据ID查找协议
function findProtocolById(sprotoInstance, id) {
    if (!sprotoInstance || !sprotoInstance.proto) {
        return null;
    }
    
    for (let i = 0; i < sprotoInstance.proto.length; i++) {
        if (sprotoInstance.proto[i].tag === id) {
            return sprotoInstance.proto[i];
        }
    }
    return null;
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
