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
                switch(message.type) {
                    case 4:  // 踢出消息
                        appendMessage('系统', message.message);
                        ws.close();
                        logout();
                        break;
                    case 1:  // 回显消息
                    case 2:  // 机器人控制响应
                    case 3:  // 机器人消息
                        appendMessage('服务器', message.message);
                        break;
                    default:
                        appendMessage('服务器', `未知类型消息: ${message.type}, 内容: ${message.message}`);
                }
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
            appendMessage('客户端', `类型: ${msgType}, 消息: ${msgContent}`);
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

// 导出需要的函数和变量
window.connectWebSocket = connectWebSocket;
window.sendMessage = sendMessage; 
window.sendMessageByType = sendMessageByType;