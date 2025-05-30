#!/bin/bash

# 检查是否以 root 用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以 root 用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到 root 用户，然后再次运行此脚本。"
    exit 1
fi

# 脚本保存路径
SCRIPT_PATH="$HOME/Blockcast.sh"

# 主菜单函数
main_menu() {
    while true; do
        clear
        echo "脚本由哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "1. 安装部署节点"
        echo "2. 查看日志"
        echo "3. 注册节点"
        echo "================================================================"
        read -p "请输入选项 (1-3): " choice
        case $choice in
            1)
                install_node
                ;;
            2)
                view_logs
                ;;
            3)
                register_node
                ;;
            *)
                echo "无效选项，请输入 1、2 或 3"
                sleep 2
                ;;
        esac
    done
}

# 安装部署节点函数
install_node() {
    # 更新系统并安装基本依赖
    echo "正在更新系统并安装依赖..."
    apt-get update && apt-get upgrade -y
    apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev iproute2 -y

    # 检查 Docker 是否安装
    if ! command -v docker &> /dev/null; then
        echo "Docker 未安装，正在安装..."
        apt-get install -y docker.io
        systemctl start docker
        systemctl enable docker
        echo "Docker 安装完成并已启用"
    else
        echo "Docker 已安装"
    fi

    # 检查 Docker Compose 是否安装
    if ! command -v docker-compose &> /dev/null; then
        echo "Docker Compose 未安装，正在安装..."
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        echo "Docker Compose 安装完成"
    else
        echo "Docker Compose 已安装"
    fi

    # 验证 Docker 和 Docker Compose 版本
    echo "验证 Docker 和 Docker Compose 版本..."
    docker --version
    docker-compose --version

    # 拉取 Blockcast 仓库
    echo "正在拉取 Blockcast 仓库..."
    if [ -d "Blockcast" ]; then
        echo "Blockcast 目录已存在，跳过克隆"
    else
        git clone https://github.com/sdohuajia/Blockcast.git
        if [ $? -ne 0 ]; then
            echo "错误：克隆 Blockcast 仓库失败！请检查网络或仓库地址。"
            exit 1
        fi
        echo "Blockcast 仓库拉取完成"
    fi

    # 进入 Blockcast 目录
    cd Blockcast || { echo "进入 Blockcast 目录失败"; exit 1; }
    echo "已进入 Blockcast 目录"

    # 检查 docker-compose 文件（支持 .yml 和 .yaml）
    COMPOSE_FILE=""
    if [ -f "/root/Blockcast/docker-compose.yml" ]; then
        COMPOSE_FILE="/root/Blockcast/docker-compose.yml"
    elif [ -f "/root/Blockcast/docker-compose.yaml" ]; then
        COMPOSE_FILE="/root/Blockcast/docker-compose.yaml"
    else
        echo "错误：/root/Blockcast/docker-compose.yml 或 /root/Blockcast/docker-compose.yaml 文件不存在！"
        exit 1
    fi
    echo "找到 docker-compose 文件：$COMPOSE_FILE"

    # 检查和调整 9090 端口
    PORT=9090
    MAX_PORT=9190  # 设置最大端口范围，防止无限递增
    while [ $PORT -le $MAX_PORT ]; do
        echo "正在检查 $PORT 端口..."
        if ss -tuln | grep -q ":$PORT "; then
            echo "警告：$PORT 端口已被占用，尝试下一个端口..."
            PORT=$((PORT + 1))
        else
            echo "$PORT 端口未被占用，使用此端口..."
            # 修改 docker-compose 文件中的端口
            sed -i "s/- \"[0-9]\+:8080\"/- \"$PORT:8080\"/g" "$COMPOSE_FILE"
            echo "已将 $COMPOSE_FILE 中的端口修改为 $PORT:8080"
            break
        fi
    done

    # 如果超过最大端口范围仍未找到可用端口
    if [ $PORT -gt $MAX_PORT ]; then
        echo "错误：未找到可用端口（尝试了 9090-$MAX_PORT）。请手动释放端口或修改配置后重试。"
        exit 1
    fi

    # 执行 docker-compose up -d
    echo "正在启动 Docker Compose 服务..."
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" up -d || { echo "错误：docker-compose up -d 执行失败！"; exit 1; }
    else
        docker compose -f "$COMPOSE_FILE" up -d || { echo "错误：docker compose up -d 执行失败！"; exit 1; }
    fi
    echo "Docker Compose 服务已启动"

    echo "节点安装部署完成！当前工作目录：$(pwd)，使用的端口：$PORT"
    read -p "按 Enter 返回主菜单..."
}

# 查看日志函数
view_logs() {
    echo "正在查看容器 watchtower 的日志（最近 1000 行）..."
    if docker ps -a | grep -q "watchtower"; then
        docker logs --tail 1000 watchtower
    else
        echo "错误：容器 watchtower 不存在或未运行！"
        echo "请先运行选项 1 安装部署节点，或检查容器名称是否正确。"
        echo "当前运行的容器："
        docker ps -a
    fi
    read -p "按 Enter 返回主菜单..."
}

# 注册节点函数
register_node() {
    # 输出当前工作目录以便调试
    echo "当前工作目录：$(pwd)"

    # 检查 docker-compose 文件（支持 .yml 和 .yaml）
    COMPOSE_FILE=""
    if [ -f "/root/Blockcast/docker-compose.yml" ]; then
        COMPOSE_FILE="/root/Blockcast/docker-compose.yml"
    elif [ -f "/root/Blockcast/docker-compose.yaml" ]; then
        COMPOSE_FILE="/root/Blockcast/docker-compose.yaml"
    else
        echo "错误：/root/Blockcast/docker-compose.yml 或 /root/Blockcast/docker-compose.yaml 文件不存在！"
        read -p "按 Enter 返回主菜单..."
        return
    fi
    echo "找到 docker-compose 文件：$COMPOSE_FILE"

    # 验证文件是否可读
    if [ ! -r "$COMPOSE_FILE" ]; then
        echo "错误：docker-compose 文件 $COMPOSE_FILE 不可读！请检查文件权限。"
        read -p "按 Enter 返回主菜单..."
        return
    fi

    # 检查服务是否运行
    if ! docker ps | grep -q "blockcastd"; then
        echo "错误：blockcastd 容器未运行！请先运行选项 1 安装部署节点。"
        echo "当前运行的容器："
        docker ps -a
        read -p "按 Enter 返回主菜单..."
        return
    fi

    # 获取地理位置
    echo "正在获取地理位置信息..."
    if ! curl -s https://ipinfo.io | jq '.city, .region, .country, .loc'; then
        echo "警告：无法获取地理位置信息，继续执行注册..."
    fi

    # 执行节点初始化和注册
    echo "正在初始化和注册节点..."
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" exec blockcastd blockcastd init || { echo "错误：节点初始化失败！"; read -p "按 Enter 返回主菜单..."; return; }
    else
        docker compose -f "$COMPOSE_FILE" exec blockcastd blockcastd init || { echo "错误：节点初始化失败！"; read -p "按 Enter 返回主菜单..."; return; }
    fi
    echo "节点初始化和注册完成！"

    read -p "按 Enter 返回主菜单..."
}

# 执行主菜单
main_menu
