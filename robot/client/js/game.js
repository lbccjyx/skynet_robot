class GameScene extends Phaser.Scene {
    constructor() {
        super({ key: 'GameScene' });
        this.background = null;
        this.chengqiang = null;  // 添加城墙引用
    }

    preload() {
        // 添加加载进度事件
        this.load.on('progress', (value) => {
            console.log('Loading progress:', value);
        });

        // 添加加载完成事件
        this.load.on('complete', () => {
            console.log('Loading complete');
        });

        // 使用配置的资源服务器URL加载资源
        const imageUrl = `${SERVER_CONFIG.getAssetsUrl()}/assets/background.png`;
        const image_chengqiang_Url = `${SERVER_CONFIG.getAssetsUrl()}/assets/chengqiang.png`;
        const image_guanfu_Url = `${SERVER_CONFIG.getAssetsUrl()}/assets/guanfu.png`;
        console.log('Attempting to load image from:', imageUrl);
        
        // 直接加载图片，不进行预检查
        this.load.image('background', imageUrl, {
            crossOrigin: 'anonymous'  // 添加跨域支持
        });

        
        this.load.image('chengqiang', image_chengqiang_Url, {
            crossOrigin: 'anonymous'  // 添加跨域支持
        });
        
        this.load.image('guanfu', image_guanfu_Url, {
            crossOrigin: 'anonymous'  // 添加跨域支持
        });
        
        // 添加加载错误处理
        this.load.on('loaderror', (fileObj) => {
            console.error('Failed to load asset:', fileObj.src);
            appendMessage('错误', '背景图片加载失败，请确保Python服务器正在运行');
        });
    }

    create() {
        try {
            // 创建背景
            this.background = this.add.image(this.cameras.main.width / 2, this.cameras.main.height / 2, 'background');
             //this.background.setOrigin(0, 0);
            this.background.setScale(1.2);  // 同时设置X和Y方向的缩放

            // 创建城墙并居中
            this.chengqiang = this.add.image(
                this.cameras.main.width / 2 - 20,  // 水平居中
                this.cameras.main.height / 2 + 10,  // 垂直居中
                'chengqiang'
            );
            this.chengqiang.setOrigin(0.5, 0.5);  // 设置原点为中心
            this.chengqiang.setScale(1.5);  // 同时设置X和Y方向的缩放
            
            // 创建官府并居中
            this.guanfu = this.add.image(
                this.cameras.main.width / 2 + 100,  // 水平居中
                this.cameras.main.height / 2 - 60,  // 垂直居中
                'guanfu'
            );
            this.guanfu.setScale(0.6); 
            
            // 设置可交互，并启用像素完美点击检测
            this.chengqiang.setInteractive({ pixelPerfect: true });
            this.guanfu.setInteractive({ pixelPerfect: true });
            
            // 添加城墙点击事件
            this.chengqiang.on('pointerdown', (pointer) => { 
                console.log('城墙被点击');
                if (typeof window.sendMessageByType === 'function') {
                    window.sendMessageByType(1, 'chengqiang');
                    window.sendMessageByType(5, 'chengqiang');
                } 
            });
            
            // 添加官府点击事件
            this.guanfu.on('pointerdown', (pointer) => {
                console.log('官府被点击');
                if (typeof window.sendMessageByType === 'function') {
                    window.sendMessageByType(1, 'guanfu');
                    window.sendMessageByType(5, 'guanfu');
                }
            });
            
            // 监听窗口大小变化
            // window.addEventListener('resize', () => this.resizeBackground());
        } catch (error) {
            console.error('Error in create:', error);
            appendMessage('错误', '创建游戏场景时发生错误');
        }
    }

    resizeBackground() {
        if (this.background) {
            const width = window.innerWidth;
            const height = window.innerHeight;
            this.background.setDisplaySize(width, height);
            
            // 同时更新城墙位置
            if (this.chengqiang) {
                this.chengqiang.setPosition(width / 2, height / 2);
            }
        }
    }
}

// 游戏配置
const config = {
    type: Phaser.AUTO,
    parent: 'gameContainer',
    width: window.innerWidth,
    height: window.innerHeight,
    scene: GameScene,
    transparent: true
};

// 创建游戏实例
let game = null;

// 显示游戏面板
function showGame() {
    document.getElementById('loginPanel').style.display = 'none';
    document.getElementById('registerPanel').style.display = 'none';
    document.getElementById('gamePanel').style.display = 'block';
    
    if (!game) {
        game = new Phaser.Game(config);
    }
}

// 隐藏游戏面板
function hideGame() {
    document.getElementById('gamePanel').style.display = 'none';
    if (game) {
        game.destroy(true);
        game = null;
    }
} 