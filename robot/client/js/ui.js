import { SERVER_CONFIG } from './config.js';
import { encodeSprotoAuth, decodeSprotoAuthResponse } from './proto.js';
import { connectWebSocket } from './websocket.js';
import { sendMessage } from './websocket.js';
import { showGame, hideGame } from './game.js';

// UI 状态切换函数
function showLogin() {
    const registerPanel = document.getElementById('registerPanel');
    const loginPanel = document.getElementById('loginPanel');
    
    if (registerPanel) {
        registerPanel.style.display = 'none';
    }
    if (loginPanel) {
        loginPanel.style.display = 'block';
    }
}

function showRegister() {
    const loginPanel = document.getElementById('loginPanel');
    const registerPanel = document.getElementById('registerPanel');
    
    if (loginPanel) {
        loginPanel.style.display = 'none';
    }
    if (registerPanel) {
        registerPanel.style.display = 'block';
    }
}

// 消息显示函数
export function appendMessage(sender, message) {
    const messageArea = document.getElementById('messageArea');
    if (!messageArea) {
        console.warn('Message area not found');
        return;
    }
    
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
    
    messageArea.appendChild(div);
    messageArea.scrollTop = messageArea.scrollHeight;
}

// 登录相关函数
async function login() {
    const username = document.getElementById('loginUsername').value;
    const password = document.getElementById('loginPassword').value;
    
    try {
        const buffer = encodeSprotoAuth(2, username, password);  // type 2 for login
        const response = await fetch(`${SERVER_CONFIG.getAuthUrl()}/auth`, {
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
            ws_host: `${SERVER_CONFIG.getWsUrl()}/test_websocket`
        };
        
        // 连接WebSocket
        connectWebSocket(wsInfo);
        
        // 显示游戏界面
        showGame();
        
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
        const response = await fetch(`${SERVER_CONFIG.getAuthUrl()}/auth`, {
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
            alert('注册成功！请登录');
            showLogin();
        } else {
            alert(responseData.message);
        }
    } catch (error) {
        console.error('Register error:', error);
        alert('注册失败: ' + error.message);
    }
}

// 登出函数
function logout() {
    // 断开WebSocket连接
    if (ws) {
        ws.close();
        ws = null;
    }
    hideGame();

    // 显示登录面板
    showLogin();
    
    appendMessage("系统", "已登出");
}

// 初始化事件监听器
function initializeEventListeners() {
    // 登录按钮
    const loginBtn = document.getElementById('loginBtn');
    if (loginBtn) {
        loginBtn.addEventListener('click', login);
    }

    // 注册按钮
    const registerBtn = document.getElementById('registerBtn');
    if (registerBtn) {
        registerBtn.addEventListener('click', register);
    }

    // 显示注册按钮
    const showRegisterBtn = document.getElementById('showRegisterBtn');
    if (showRegisterBtn) {
        showRegisterBtn.addEventListener('click', showRegister);
    }

    // 显示登录按钮
    const showLoginBtn = document.getElementById('showLoginBtn');
    if (showLoginBtn) {
        showLoginBtn.addEventListener('click', showLogin);
    }

    // 登出按钮
    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', logout);
    }

    // 发送消息按钮
    const sendBtn = document.getElementById('sendBtn');
    if (sendBtn) {
        sendBtn.addEventListener('click', sendMessage);
    }

    // 消息输入框回车事件
    const messageInput = document.getElementById('messageInput');
    if (messageInput) {
        messageInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                sendMessage();
            }
        });
    }
}

// 等待DOM加载完成后再初始化
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeEventListeners);
} else {
    initializeEventListeners();
}

// 初始化时显示登录面板
showLogin();

// 导出需要的函数
window.showLogin = showLogin;
window.showRegister = showRegister;
window.appendMessage = appendMessage;
window.login = login;
window.register = register;
window.logout = logout; 