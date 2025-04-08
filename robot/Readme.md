这是一个开发进度0.1%的游戏, 玩家可以注册登录。然后当我们在页面输入1 + 语句 可以得到原本的string
当我们在页面输入 2+num 可以在这个玩家上创建 num个机器人。现在自然是没什么用了。机器人就算是NPC把。比如我们有一座城池，里面的每个NPC都可以有自己的事情-现在的事情就是输出文字。然后我们是城主。城主的逻辑还没写。NPC的逻辑也还没写。

先下载 https://github.com/cloudwu/skynet.git 然后进入skynet 这里我叫他 工作目录
然后下载本skynet_robot 然后重命名 skynet_rebot 改名为 robot 放入  工作目录。
 工作目录下 命令: make 'linux'
 工作目录下 命令: ./skynet robot/config 对了这样肯定是跑不起来的。还需要在linux上部署mysql-service 然后按照 robot/config 上面的配置去创建数据库。
 表结构也还没写。
