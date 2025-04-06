// UI 状态切换函数
function showLogin() {
    document.getElementById('registerPanel').style.display = 'none';
    document.getElementById('loginPanel').style.display = 'block';
}

function showRegister() {
    document.getElementById('loginPanel').style.display = 'none';
    document.getElementById('registerPanel').style.display = 'block';
}

// 消息显示函数
function appendMessage(sender, message) {
    const div = document.createElement('div');
    div.textContent = `${sender}: ${message}`;
    
    if (sender === '服务器' && message.includes('robot')) {
        if (message.includes('sleeping') || message.includes('woke up') || message.includes('stopped')) {
            div.className = 'message robot-status';
        } else {
            div.className = 'message robot-message';
        }
    } else {
        div.className = `message ${sender.toLowerCase()}`;
    }
    
    const messageArea = document.getElementById('messageArea');
    messageArea.appendChild(div);
    messageArea.scrollTop = messageArea.scrollHeight;
}

// 登录相关函数
async function login() {
    const username = document.getElementById('loginUsername').value;
    const password = document.getElementById('loginPassword').value;
    
    try {
        const buffer = encodeSprotoAuth(2, username, password);  // type 2 for login
        const response = await fetch('http://192.168.3.43:8080/auth', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-sproto',
            },
            body: buffer
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const responseBuffer = await response.arrayBuffer();
        const responseData = decodeSprotoAuthResponse(responseBuffer);
        
        if (responseData.code === 200) {
            handleLoginResponse(responseData);
        } else {
            alert(responseData.message);
        }
    } catch (error) {
        console.error('Login error:', error);
        alert('登录失败: ' + error.message);
    }
}

function handleLoginResponse(response) {
    if (response.code === 200) {
        // 解析登录响应
        const wsInfo = {
            token: response.message,  // 使用msg作为token
            ws_host: `ws://192.168.3.43:9948/test_websocket`
        };
        
        // 连接WebSocket
        connectWebSocket(wsInfo);
        
        // 显示主面板
        document.getElementById('loginPanel').style.display = 'none';
        document.getElementById('mainPanel').style.display = 'block';
        
        appendMessage("系统", "登录成功！");
    } else {
        appendMessage("错误", response.message);
    }
}

// 注册相关函数
async function register() {
    const username = document.getElementById('registerUsername').value;
    const password = document.getElementById('registerPassword').value;
    const confirmPassword = document.getElementById('confirmPassword').value;
    
    if (password !== confirmPassword) {
        alert('两次输入的密码不一致');
        return;
    }
    
    try {
        const buffer = encodeSprotoAuth(1, username, password);  // type 1 for register
        const response = await fetch('http://192.168.3.43:8080/auth', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-sproto',
            },
            body: buffer
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const responseBuffer = await response.arrayBuffer();
        const responseData = decodeSprotoAuthResponse(responseBuffer);
        
        if (responseData.code === 200) {
            alert('注册成功，请登录');
            showLogin();
        } else {
            alert(responseData.msg);
        }
    } catch (error) {
        console.error('Register error:', error);
        alert('注册失败: ' + error.message);
    }
}

// 登出函数
function logout() {
    if (ws) {
        ws.close();
        ws = null;
    }
    currentUser = null;
    document.getElementById('mainPanel').style.display = 'none';
    document.getElementById('loginPanel').style.display = 'block';
    document.getElementById('messageArea').innerHTML = '';
}

// 事件监听器设置
document.addEventListener('DOMContentLoaded', function() {
    document.getElementById('messageInput').addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            sendMessage();
        }
    });
});

// 导出需要的函数
window.showLogin = showLogin;
window.showRegister = showRegister;
window.appendMessage = appendMessage;
window.login = login;
window.register = register;
window.logout = logout; 