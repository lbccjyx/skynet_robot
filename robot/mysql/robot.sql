-- 创建用户-机器人关联表
DROP TABLE IF EXISTS d_user_robot_link;
CREATE TABLE d_user_robot_link (
    user_id INT NOT NULL,
    robot_id INT NOT NULL,
    PRIMARY KEY (user_id, robot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 创建用户表
DROP TABLE IF EXISTS d_user;
CREATE TABLE d_user (
    user_id INT NOT NULL AUTO_INCREMENT,
    user_name VARCHAR(50) NOT NULL,
    user_password VARCHAR(255) NOT NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY (user_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO d_user (user_id, user_name, user_password) VALUES 
(1, "1", "1");

-- 创建机器人表
DROP TABLE IF EXISTS d_user_robot;
CREATE TABLE d_user_robot (
    robot_id INT NOT NULL,
    age INT,
    gender VARCHAR(10),
    PRIMARY KEY (robot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 建筑基础表
DROP TABLE IF EXISTS s_struct;
CREATE TABLE s_struct (
    id INT NOT NULL AUTO_INCREMENT,
    struct_id INT NOT NULL COMMENT '建筑ID',
    cn_name VARCHAR(50) NOT NULL COMMENT '建筑名称', 
    str_name VARCHAR(50) NOT NULL COMMENT '建筑代称', 
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='建筑基础表';

-- 插入一些基础建筑数据
INSERT INTO s_struct ( struct_id, cn_name, str_name) VALUES 
(1, '城墙', "chengqiang"),
(2, '官府', "guanfu");

-- 建筑升级表
DROP TABLE IF EXISTS s_struct_upgrade;
CREATE TABLE s_struct_upgrade (
    id INT NOT NULL AUTO_INCREMENT,
    struct_id INT NOT NULL COMMENT '建筑ID',
    lev INT NOT NULL COMMENT '当前等级',
    cost_type1 VARCHAR(20) COMMENT '升级所需资源类型1',
    cost_num1 INT COMMENT '升级所需资源数量1',
    cost_type2 VARCHAR(20) COMMENT '升级所需资源类型2',
    cost_num2 INT COMMENT '升级所需资源数量2',
    cost_type3 VARCHAR(20) COMMENT '升级所需资源类型3',
    cost_num3 INT COMMENT '升级所需资源数量3',
    cost_type4 VARCHAR(20) COMMENT '升级所需资源类型4',
    cost_num4 INT COMMENT '升级所需资源数量4',
    cost_sec INT NOT NULL COMMENT '升级所需时间(秒)',
    hp INT NOT NULL COMMENT '建筑血量',
    `image` VARCHAR(100) COMMENT '建筑图片路径',
    PRIMARY KEY (id),
    UNIQUE KEY (struct_id, lev)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='建筑升级表';

-- 玩家建筑表
DROP TABLE IF EXISTS d_user_struct;
CREATE TABLE d_user_struct (
    id INT NOT NULL AUTO_INCREMENT,
    user_id INT NOT NULL COMMENT '用户ID',
    struct_id INT NOT NULL COMMENT '建筑ID',
    lev INT NOT NULL DEFAULT 1 COMMENT '当前等级',
    upgrade_end_time BIGINT COMMENT '升级结束时间戳',
    current_hp INT NOT NULL COMMENT '当前血量',
    PRIMARY KEY (id),
    UNIQUE KEY (user_id, struct_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='玩家建筑表';

-- 物品基础表
DROP TABLE IF EXISTS s_item;
CREATE TABLE s_item (
    id INT NOT NULL AUTO_INCREMENT,
    item_id INT NOT NULL COMMENT '物品ID',
    cn_name VARCHAR(50) NOT NULL COMMENT '物品名称',
    str_name VARCHAR(50) NOT NULL COMMENT '物品代称',
    `image` VARCHAR(100) COMMENT '物品图标路径',
    stackable BOOLEAN NOT NULL DEFAULT TRUE COMMENT '是否可叠加',
    PRIMARY KEY (id),
    UNIQUE KEY (str_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物品基础表';

-- 玩家物品表
DROP TABLE IF EXISTS d_user_item;
CREATE TABLE d_user_item (
    id INT NOT NULL AUTO_INCREMENT,
    user_id INT NOT NULL COMMENT '用户ID',
    item_id INT NOT NULL COMMENT '物品ID',
    amount INT NOT NULL DEFAULT 0 COMMENT '物品数量',
    PRIMARY KEY (id),
    KEY (user_id, item_id),
    KEY (item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='玩家物品表';


-- 插入城墙升级数据
INSERT INTO s_struct_upgrade (struct_id, lev, cost_type1, cost_num1, cost_sec, hp, `image`) VALUES 
(1, 1, 'gold', 100, 60, 1000, 'chengqiang_lv1.png'),
(1, 2, 'gold', 200, 120, 2000, 'chengqiang_lv2.png'),
(1, 3, 'gold', 400, 180, 4000, 'chengqiang_lv3.png'),
(2, 1, 'gold', 150, 60, 800, 'guanfu_lv1.png'),
(2, 2, 'gold', 300, 120, 1600, 'guanfu_lv2.png'),
(2, 3, 'gold', 600, 180, 3200, 'guanfu_lv3.png');

-- 插入基础物品数据
INSERT INTO s_item (item_id, cn_name, str_name, `image`, stackable) VALUES 
(1, '金币', 'gold', 'gold.png', true),
(2, '木材', 'wood', 'wood.png', true),
(3, '石头', 'stone', 'stone.png', true),
(4, '铁矿', 'iron', 'iron.png', true);

-- 执行命令： 
-- mysql -u skynet -pPassword123 -h localhost PlayerDatabase < robot/mysql/robot.sql
-- mysql -u skynet -pPassword123 -h localhost PlayerDatabase
