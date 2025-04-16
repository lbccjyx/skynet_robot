import { SERVER_CONFIG } from './config.js';
import { ConnectWebSocket, SendProtoMessage } from './websocket.js';
import { showGame, hideGame } from './game.js';
import { initSproto } from './sproto-helper.js'; // 新增 sproto 初始化模块
import { PROTOCOL, NORMAL_MSG_TYPE } from './enums.js';

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
        const response = await fetch(`${SERVER_CONFIG.getAuthUrl()}/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            mode: 'cors',  // 添加 CORS 模式
            credentials: 'omit',  // 不发送 cookies
            body: JSON.stringify({
                username: username,
                password: password
            })
        });
        
        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ message: 'Unknown error' }));
            throw new Error(errorData.message || `HTTP error! status: ${response.status}`);
        }
        
        const responseData = await response.json();
        console.log('Login response:', responseData);  // 添加调试日志
        
        if (responseData.success) {
            handleLoginResponse(responseData);
        } else {
            alert(responseData.message || 'Login failed');
        }
    } catch (error) {
        console.error('Login error:', error);
        appendMessage('错误', '登录失败: ' + error.message);
    }
}

function handleLoginResponse(response) {
    if (response.success) {
        try {
            // 初始化 sproto
            const sprotoInstance = initSproto(response.sproto_desc);
            if (!sprotoInstance) {
                throw new Error('Failed to initialize Sproto');
            }
            
            // 连接 WebSocket
            const wsInfo = {
                token: response.token,
                ws_host: `${SERVER_CONFIG.getWsUrl()}/ws?token=${response.token}`
            };
            ConnectWebSocket(wsInfo);
            
            // 显示游戏界面
            showGame();
            
            appendMessage("系统", "登录成功！");
        } catch (e) {
            console.error('Failed to init sproto:', e);
            appendMessage("错误", '协议初始化失败: ' + e.message);
        }
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
        const response = await fetch(`${SERVER_CONFIG.getAuthUrl()}/register`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                username: username,
                password: password
            })
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const responseData = await response.json();
        
        if (responseData.success) {
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
    if (window.ws) {
        window.ws.close();
        window.ws = null;
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
        sendBtn.addEventListener('click', function() {
            const messageInput = document.getElementById('messageInput');
            if (messageInput) {
                try {
                    const message = messageInput.value.trim();
                    if (!message) {
                        console.log('消息内容为空，不发送');
                        return;
                    }
                    
                    // 确保消息格式符合WsMessage结构
                    const wsMessage = {
                        type: NORMAL_MSG_TYPE.WS_MESSAGE,  // integer
                        message: message                    // string
                    };
                    
                    SendProtoMessage(PROTOCOL.NORMAL_REQ, wsMessage);
                    
                    // 清空输入框
                    messageInput.value = '';
                } catch (error) {
                    console.error('发送消息失败:', error);
                    appendMessage('系统', '发送消息失败: ' + error.message);
                }
            }
        });
    }

    // 消息输入框回车事件
    const messageInput = document.getElementById('messageInput');
    if (messageInput) {
        messageInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                try {
                    const message = messageInput.value.trim();
                    if (!message) {
                        console.log('消息内容为空，不发送');
                        return;
                    }
                    
                    // 确保消息格式符合WsMessage结构
                    const wsMessage = {
                        type: NORMAL_MSG_TYPE.WS_MESSAGE,  // integer
                        message: message                    // string
                    };
                    
                    SendProtoMessage(PROTOCOL.NORMAL_REQ, wsMessage);
                    
                    // 清空输入框
                    messageInput.value = '';
                } catch (error) {
                    console.error('发送消息失败:', error);
                    appendMessage('系统', '发送消息失败: ' + error.message);
                }
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