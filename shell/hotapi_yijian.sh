#!/bin/bash
# 获取当前系统信息
echo "正在获取当前系统信息..."
uname -a
cat /etc/os-release

# 检查并安装 Node.js 和 npm
echo "正在检查 Node.js 和 npm 环境..."
if ! command -v node &> /dev/null; then
  echo "Node.js 未安装，开始安装..."
  # 如果是Debian 11,需要更新 Node.js 版本
  version=$(grep -oP '(?<=VERSION_ID=").*(?=")' /etc/os-release)

  echo "版本 》》》 ${version}"
  # 判断系统版本并执行相应操作
  if [[ $version == "20.04" ]]; then
    echo "这是 Ubuntu 20.04 版本"
    # 执行 Ubuntu 20.04 版本的操作
    # 从 NodeSource 服务下载需要的 Node.js 安装脚本。注意更换版本号。当前的 LTS 版本是 18.x
    curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  elif [[ $version == "11" ]]; then
    echo "这是 Debian GNU/Linux 11 版本"
    # 从 NodeSource 服务下载需要的 Node.js 安装脚本。注意更换版本号。当前的 LTS 版本是 18.x
    curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    # 现在可以直接从 apt 安装（更新）noedjs
    # 接下来和其他系统一样的操作了
  else
    echo "这是其他版本的系统"
    # 执行其他版本系统的操作
    # 在这里添加您要执行的命令或操作
  fi

  apt-get update
  apt-get install -y nodejs npm
  echo "Node.js 安装完成！"
else
  echo "Node.js 已安装，版本：$(node --version)"
fi

if ! command -v npm &> /dev/null; then
  echo "npm 未安装，开始安装..."
  apt-get install -y npm
  echo "npm 安装完成！"
else
  echo "npm 已安装，版本：$(npm --version)"
fi

# 首先检查/opt/DailyAPI文件夹是否存在
echo "首先检查/opt/DailyAPI文件夹是否存在..."
if [[ ! -d "/opt/DailyAPI" ]]; then
  echo "正在克隆 DailyAPI 仓库..."
  git clone https://github.com/bizhangjie/DailyAPI.git /opt/DailyAPI
  echo "克隆完成！"
fi
echo "已经下载完毕！！！"

# 然后进入文件夹
echo "准备进入/opt/DailyAPI中..."
cd /opt/DailyAPI
echo "已进入/opt/DailyAPI中啦！"

# 请求用户输入端口号
read -p "请输入端口号（按回车键设置默认端口）: " port

# 如果用户未输入端口号，则使用默认端口
if [ -z "$port" ]; then
    port="8888"
fi

# 先删除.env文件
rm -rf .env
# 将端口号写入新的.env文件
echo "# 服务端口" > .env
echo "PORT=$port" >> .env
echo "" >> .env
echo "# 允许的域名" >> .env
echo "ALLOWED_DOMAIN=*" >> .env

# 显示成功添加端口的消息
echo "已将端口号 $port 写入.env文件中"

# 获取外部IP地址
ip=$(curl ifconfig.me)

# 输出所使用的端口号和外部IP地址
echo "已设置端口号为: $port"
echo "系统外网IP地址为: $ip"

# 使用npm安装包
echo "正在安装依赖包，请稍等..."
npm install
echo "安装完成！"

# 创建DailyAPI.service文件
echo "正在创建 DailyAPI systemd 服务文件..."
cat << EOF > /etc/systemd/system/DailyAPI.service
[Unit]
Description=DailyAPI Service
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
WorkingDirectory=/opt/DailyAPI
ExecStart=/usr/bin/node index.js >> /var/log/DailyAPI.log 2>&1
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
echo "服务文件创建完成！/etc/systemd/system/DailyAPI.service"

# 命令重新加载服务配置
echo "命令重新加载服务配置..."
systemctl daemon-reload
echo "命令重新加载服务配置完成!!!"

# 启用并启动服务
echo "正在启用 DailyAPI 服务..."
systemctl enable DailyAPI
echo "启用完成！"

echo "正在启动 DailyAPI 服务..."
systemctl start DailyAPI
echo "启动完成！"

echo "查看启动状况 DailyAPI 服务..."
systemctl status DailyAPI
echo "如果是 => Active: active (running) 代表启动成功！！！"

echo "一键直达(直接访问) ==> http:[$ip]:$port"
