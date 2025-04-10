import { MSG_TYPE } from './enums.js';
import { encodeMessage, decodeMessage, encodeNormalPos } from './proto.js';
import { appendMessage } from './ui.js';

let ws = null;
let currentWsInfo = null;


function connectWebSocket(info) {
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
            console.log("Received message type:", typeof event.data);
            if (event.data instanceof ArrayBuffer) {
                const message = decodeMessage(event.data);
                handleServerMessage(message);
            } else {
                appendMessage('服务器', event.data);
            }
        } catch (err) {
            console.error("Failed to process message:", err);
            console.error("Error details:", err.stack);
            appendMessage('错误', '无法处理服务器消息');
        }
    };
    
    ws.onclose = function() {
        appendMessage('系统', '连接已关闭');
        ws = null;
        
        // 如果不是主动登出，则尝试重连
        if (currentWsInfo) {
            appendMessage('系统', '尝试重新连接...');
            setTimeout(() => connectWebSocket(currentWsInfo), 3000);
        }
    };
    
    ws.onerror = function(error) {
        appendMessage('系统', '连接发生错误');
        console.error('WebSocket error:', error);
    };
}

// 处理服务器消息
function handleServerMessage(message) {
    switch (message.type) {
        case MSG_TYPE.AUTH_RESPONSE:
            handleAuthResponse(message);
            break;
        case MSG_TYPE.WS_MESSAGE:
            handleWsMessage(message);
            break;
        case MSG_TYPE.KICK_OUT:
            handleKickOut(message);
            break;
        case MSG_TYPE.ROBOT_POS:
            handleRobotPos(message);
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

// 处理WebSocket消息
function handleWsMessage(message) {
    const wsMessage = JSON.parse(message.message);
    switch (wsMessage.type) {
        case 1:  // echo
        case 2:  // create robots
        case 3:  // robot messages
            appendMessage('服务器', wsMessage.message);
            break;
        default:
            appendMessage('服务器', `未知消息类型: ${wsMessage.type}`);
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

function sendMessageByType(type, message) {
    if (!ws) {
        appendMessage('错误', '未连接到服务器');
        return;
    }
    
    // 如果提供了参数，使用参数；否则从DOM元素获取
    const msgType = type !== undefined ? type : (parseInt(document.getElementById('typeInput').value) || 1);
    const msgContent = message !== undefined ? message : document.getElementById('messageInput').value;
    
    if (msgContent) {
        try {
            const buffer = encodeMessage(msgType, msgContent);
            ws.send(buffer);
            // appendMessage('客户端', `类型: ${msgType}, 消息: ${msgContent}`);
            // 只有在没有提供参数时才清空输入框
            if (message === undefined) {
                document.getElementById('messageInput').value = '';
            }
        } catch (err) {
            console.error("Failed to encode message:", err);
            appendMessage('错误', '消息编码失败');
        }
    }
}

function sendMessage() {
    if (!ws) {
        appendMessage('错误', '未连接到服务器');
        return;
    }
    
    const type = parseInt(document.getElementById('typeInput').value) || 1;
    const message = document.getElementById('messageInput').value;
    
    if (message) {
        try {
            const buffer = encodeMessage(type, message);
            ws.send(buffer);
            appendMessage('客户端', `类型: ${type}, 消息: ${message}`);
            document.getElementById('messageInput').value = '';
        } catch (err) {
            console.error("Failed to encode message:", err);
            appendMessage('错误', '消息编码失败');
        }
    }
}

// 发送NormalPos消息
function sendNormalPos(normalPos) {
    if (!ws) {
        appendMessage('错误', '未连接到服务器');
        return;
    }
    
    try {
        const buffer = encodeNormalPos(normalPos);
        ws.send(buffer);
    } catch (err) {
        console.error("Failed to encode NormalPos message:", err);
        appendMessage('错误', '消息编码失败');
    }
}

// 导出需要的函数和变量
export { connectWebSocket, sendMessage, sendMessageByType, sendNormalPos };
