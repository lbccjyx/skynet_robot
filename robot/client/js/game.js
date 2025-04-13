import { SERVER_CONFIG } from './config.js';
import { appendMessage } from './ui.js';
import { SendProtoMessage } from './websocket.js';
import { PROTOCOL } from './enums.js';

class GameScene extends Phaser.Scene {
    constructor() {
        super({ key: 'GameScene' });
        this.background = null;
        this.chengqiang = null;  // 添加城墙引用
        this.people = null;
        this.moveTimer = null;
        this.currentDirection = 'down';  // 初始方向
        this.robots = new Map();  // 存储所有机器人精灵
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
            frameWidth: 32,  // 96/3
            frameHeight: 48  // 192/4
        });
    }

    create() {
        try {
            // 创建背景
            this.background = this.add.image(this.cameras.main.width / 2, this.cameras.main.height / 2, 'background');
            this.background.setScale(1.2);

            // 创建城墙并居中
            this.chengqiang = this.add.image(
                this.cameras.main.width / 2 - 20,
                this.cameras.main.height / 2 + 10,
                'chengqiang'
            );
            this.chengqiang.setOrigin(0.5, 0.5);
            this.chengqiang.setScale(1.5);

            // 创建官府并居中
            this.guanfu = this.add.image(
                this.cameras.main.width / 2 + 100,
                this.cameras.main.height / 2 - 60,
                'guanfu'
            );
            this.guanfu.setScale(0.6);
            
            // 设置可交互，并启用像素完美点击检测
            this.chengqiang.setInteractive({ pixelPerfect: true });
            this.guanfu.setInteractive({ pixelPerfect: true });
        
            // 发送城墙位置信息
            this.sendWallPosition();

            // 添加城墙点击事件
            this.chengqiang.on('pointerdown', (pointer) => { 
                console.log('城墙被点击');
                // 发送城墙位置信息
                // this.sendWallPosition();
            });
            
            // 添加官府点击事件
            this.guanfu.on('pointerdown', (pointer) => {
                console.log('官府被点击');
                SendProtoMessage(PROTOCOL.NORMAL_REQ, {type: 5, message: 'guanfu'});
            });
            
            // 创建人物精灵
            this.people = this.add.sprite(400, 300, 'people');
            this.people.setScale(0.3);

            // 创建动画
            this.createAnimations();
            
            // 无需监听窗口大小变化
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

    sendWallPosition() {
        const bounds = this.chengqiang.getBounds();
        const normalPos = {
            pos_L_U_x: bounds.x,
            pos_L_U_y: bounds.y,
            pos_R_U_x: bounds.x + bounds.width,
            pos_R_U_y: bounds.y,
            pos_L_D_x: bounds.x,
            pos_L_D_y: bounds.y + bounds.height,
            pos_R_D_x: bounds.x + bounds.width,
            pos_R_D_y: bounds.y + bounds.height
        };
        SendProtoMessage(PROTOCOL.NORMAL_POS_C_TO_S, normalPos);
    }

    // 更新机器人位置
    updateRobotPosition(robotPos) {
        let robot = this.robots.get(robotPos.robot_id);
        
        // 如果机器人不存在，创建新的精灵
        if (!robot) {
            robot = this.add.sprite(robotPos.posX, robotPos.posY, 'people');
            robot.setScale(0.5);
            this.robots.set(robotPos.robot_id, robot);
        }

        // 更新位置
        robot.x = robotPos.posX;
        robot.y = robotPos.posY;

        // 根据状态播放对应动画
        let animKey = 'walk_down';
        switch (robotPos.status) {
            case 1:  // 右
                animKey = 'walk_right';
                break;
            case 2:  // 下
                animKey = 'walk_down';
                break;
            case 3:  // 左
                animKey = 'walk_left';
                break;
            case 4:  // 上
                animKey = 'walk_up';
                break;
        }
        
        if (!robot.anims.isPlaying || robot.anims.currentAnim.key !== animKey) {
            robot.play(animKey);
        }
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

export { showGame, hideGame };