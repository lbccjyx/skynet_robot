class GameScene extends Phaser.Scene {
    constructor() {
        super({ key: 'GameScene' });
        this.background = null;
        this.chengqiang = null;  // 添加城墙引用
        this.people = null;
        this.moveTimer = null;
        this.currentDirection = 'down';  // 初始方向
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
        this.load.setBaseURL(SERVER_CONFIG.getAssetsUrl());        
        this.load.image('background', 'assets/background.png');        
        this.load.image('chengqiang', 'assets/chengqiang.png');        
        this.load.image('guanfu', 'assets/guanfu.png');
        
        // 添加加载错误处理
        this.load.on('loaderror', (fileObj) => {
            console.error('Failed to load asset:', fileObj.src);
            appendMessage('错误', '背景图片加载失败，请确保Python服务器正在运行');
        });

        // 加载人物图片
        this.load.spritesheet('people', 'assets/people/people.png', {
            frameWidth: 72,  // 每帧宽度
            frameHeight: 100  // 每帧高度
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
                    window.sendMessageByType(5, 'chengqiang');
                } 
            });
            
            // 添加官府点击事件
            this.guanfu.on('pointerdown', (pointer) => {
                console.log('官府被点击');
                if (typeof window.sendMessageByType === 'function') {
                    window.sendMessageByType(5, 'guanfu');
                }
            });
            
            // 创建人物精灵
            this.people = this.add.sprite(400, 300, 'people');
            this.people.setScale(0.3);  // 放大2倍

            // 创建动画
            this.createAnimations();

            // 开始随机移动
            this.startRandomMovement();
            
            // 监听窗口大小变化
            // window.addEventListener('resize', () => this.resizeBackground());
        } catch (error) {
            console.error('Error in create:', error);
            appendMessage('错误', '创建游戏场景时发生错误');
        }
    }

    createAnimations() {
        // 向下走动画
        this.anims.create({
            key: 'walk_down',
            frames: this.anims.generateFrameNumbers('people', { start: 0, end: 2 }),
            frameRate: 8,
            repeat: -1
        });

        // 向左走动画
        this.anims.create({
            key: 'walk_left',
            frames: this.anims.generateFrameNumbers('people', { start: 3, end: 5 }),
            frameRate: 8,
            repeat: -1
        });

        // 向右走动画
        this.anims.create({
            key: 'walk_right',
            frames: this.anims.generateFrameNumbers('people', { start: 6, end: 8 }),
            frameRate: 8,
            repeat: -1
        });

        // 向上走动画
        this.anims.create({
            key: 'walk_up',
            frames: this.anims.generateFrameNumbers('people', { start: 9, end: 11 }),
            frameRate: 8,
            repeat: -1
        });
    }

    startRandomMovement() {
        // 每3秒改变一次方向和位置
        this.moveTimer = this.time.addEvent({
            delay: 3000,
            callback: this.changeDirection,
            callbackScope: this,
            loop: true
        });
    }

    changeDirection() {
        // 随机选择方向
        const directions = ['up', 'down', 'left', 'right'];
        const newDirection = directions[Math.floor(Math.random() * directions.length)];
        
        // 如果方向改变，播放新的动画
        if (newDirection !== this.currentDirection) {
            this.currentDirection = newDirection;
            this.people.play(`walk_${newDirection}`);
        }

        // 计算新的位置
        let newX = this.people.x;
        let newY = this.people.y;
        const moveDistance = 100;  // 移动距离

        switch (newDirection) {
            case 'up':
                newY -= moveDistance;
                break;
            case 'down':
                newY += moveDistance;
                break;
            case 'left':
                newX -= moveDistance;
                break;
            case 'right':
                newX += moveDistance;
                break;
        }

        // 确保不超出屏幕边界
        newX = Phaser.Math.Clamp(newX, 50, 750);
        newY = Phaser.Math.Clamp(newY, 50, 550);

        // 移动到新位置
        this.tweens.add({
            targets: this.people,
            x: newX,
            y: newY,
            duration: 2000,
            ease: 'Power2'
        });
    }

    update() {
        // 可以在这里添加其他更新逻辑
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
    width: 1280,
    height: 720,
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