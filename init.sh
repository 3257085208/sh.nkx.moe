#!/bin/bash

# =========================================================
# NKX Network - VPS 综合管理脚本
# =========================================================

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# --- 检查 Root ---
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 必须使用 root 用户运行此脚本！${PLAIN}" && exit 1

# --- 1. 定义功能函数 ---

# 显示 Logo
show_logo() {
    clear
    echo -e "${CYAN}
 _   _  _  __ __   __ ${GREEN}_   _        _                      _    ${CYAN}
| \ | || |/ / \ \ / / ${GREEN}| \ | |      | |                    | |   ${CYAN}
|  \| || ' /   \ V /  ${GREEN}|  \| |  ___ | |_ __      __  ___  _ __| | __ ${CYAN}
| . \` ||  <     > <   ${GREEN}| . \` | / _ \| __|\ \ /\ / / / _ \| '__| |/ / ${CYAN}
| |\  || . \   / . \  ${GREEN}| |\  ||  __/| |_  \ V  V / | (_) | |  |   <  ${CYAN}
|_| \_||_|\_\ /_/ \_\ ${GREEN}|_| \_| \___| \__|  \_/\_/   \___/|_|  |_|\_\ ${CYAN}
${PLAIN}"
    echo -e "${BLUE}===============================================================${PLAIN}"
    echo -e "${YELLOW}       NKX Network VPS 综合管理工具箱 v1.0       ${PLAIN}"
    echo -e "${BLUE}===============================================================${PLAIN}"
}

# 功能：修改 Root 密码
func_password() {
    echo -e "\n${GREEN}> 正在执行：修改 Root 密码${PLAIN}"
    read -p "请输入新的密码: " MY_PASSWORD
    if [[ -n "$MY_PASSWORD" ]]; then
        echo "root:$MY_PASSWORD" | chpasswd
        echo -e "${GREEN}√ 密码修改成功！${PLAIN}"
    else
        echo -e "${RED}× 未输入密码，操作取消。${PLAIN}"
    fi
}

# 功能：修改 Hostname
func_hostname() {
    echo -e "\n${GREEN}> 正在执行：修改主机名${PLAIN}"
    read -p "请输入新的主机名 (默认: nkx-node): " MY_HOSTNAME
    [[ -z "$MY_HOSTNAME" ]] && MY_HOSTNAME="nkx-node"
    
    hostnamectl set-hostname "$MY_HOSTNAME"
    sed -i '/127.0.0.1/d' /etc/hosts
    echo "127.0.0.1 localhost $MY_HOSTNAME" >> /etc/hosts
    echo -e "${GREEN}√ 主机名已设置为: $MY_HOSTNAME${PLAIN}"
}

# 功能：开启 BBR + FQ
func_bbr() {
    echo -e "\n${GREEN}> 正在执行：开启 BBR 加速${PLAIN}"
    if ! grep -q "net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.conf; then
        echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
        sysctl -p >/dev/null 2>&1
        echo -e "${GREEN}√ BBR 已成功开启！${PLAIN}"
    else
        echo -e "${YELLOW}! BBR 之前已经开启过，跳过。${PLAIN}"
    fi
}

# 功能：系统基础优化 (时区+软件更新)
func_system_base() {
    echo -e "\n${GREEN}> 正在执行：系统基础优化 (时区/更新/常用工具)${PLAIN}"
    
    # 时区
    timedatectl set-timezone Asia/Shanghai
    echo -e "  - 时区设置为: Asia/Shanghai"
    
    # 常用工具安装
    echo -e "  - 正在后台更新软件源并安装 curl, wget, vim, git..."
    export DEBIAN_FRONTEND=noninteractive
    if [ -f /etc/debian_version ]; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y curl wget vim git htop unzip >/dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        yum update -y >/dev/null 2>&1
        yum install -y curl wget vim git htop unzip >/dev/null 2>&1
    fi
    echo -e "${GREEN}√ 基础环境优化完成。${PLAIN}"
}

# 功能：SSH 防掉线设置
func_ssh_keepalive() {
     echo -e "\n${GREEN}> 正在执行：SSH 防掉线配置${PLAIN}"
     grep -q "^ClientAliveInterval" /etc/ssh/sshd_config && sed -i 's/^ClientAliveInterval.*/ClientAliveInterval 60/' /etc/ssh/sshd_config || echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
     service sshd restart 2>/dev/null || systemctl restart sshd
     echo -e "${GREEN}√ SSH 配置已优化。${PLAIN}"
}

# --- 预设方案：全自动初始化 (Preset 1) ---
func_preset_1() {
    echo -e "\n${YELLOW}=== 正在运行：预设方案 1 (全自动初始化) ===${PLAIN}"
    echo -e "${CYAN}包含：改名 + 改密 + 时区 + 软件更新 + BBR + SSH优化${PLAIN}"
    
    # 1. 先问清楚所有问题
    read -p "请输入新的主机名 (回车默认 nkx-node): " P_HOSTNAME
    [[ -z "$P_HOSTNAME" ]] && P_HOSTNAME="nkx-node"
    
    read -p "请输入新的 Root 密码 (回车不修改): " P_PASSWORD
    
    echo -e "\n${YELLOW}>> 开始自动化执行...<<${PLAIN}"
    
    # 2. 执行改名
    hostnamectl set-hostname "$P_HOSTNAME"
    sed -i '/127.0.0.1/d' /etc/hosts
    echo "127.0.0.1 localhost $P_HOSTNAME" >> /etc/hosts
    echo -e "${GREEN}[1/5] 主机名设置完成${PLAIN}"
    
    # 3. 执行改密
    if [[ -n "$P_PASSWORD" ]]; then
        echo "root:$P_PASSWORD" | chpasswd
        echo -e "${GREEN}[2/5] 密码修改完成${PLAIN}"
    else
        echo -e "${YELLOW}[2/5] 跳过密码修改${PLAIN}"
    fi
    
    # 4. 执行基础优化
    func_system_base
    echo -e "${GREEN}[3/5] 系统更新与时区设置完成${PLAIN}"
    
    # 5. 执行 BBR
    func_bbr
    echo -e "${GREEN}[4/5] BBR 设置完成${PLAIN}"
    
    # 6. SSH 优化
    func_ssh_keepalive
    echo -e "${GREEN}[5/5] SSH 优化完成${PLAIN}"
    
    echo -e "\n${GREEN}=== 预设方案 1 执行完毕！===${PLAIN}"
}


# --- 2. 主菜单循环 ---

while true; do
    show_logo
    echo -e "请选择要执行的操作："
    echo -e "${GREEN}1.${PLAIN} 修改 Root 密码"
    echo -e "${GREEN}2.${PLAIN} 修改主机名 (Hostname)"
    echo -e "${GREEN}3.${PLAIN} 一键开启 BBR + FQ"
    echo -e "${GREEN}4.${PLAIN} ${YELLOW}预设方案 1 (一键全能初始化)${PLAIN} ${CYAN}<- 推荐${PLAIN}"
    echo -e "${GREEN}5.${PLAIN} SSH 防掉线优化"
    echo -e "${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -p "请输入数字 [0-5]: " choice

    case "$choice" in
        1)
            func_password
            ;;
        2)
            func_hostname
            ;;
        3)
            func_bbr
            ;;
        4)
            func_preset_1
            ;;
        5)
            func_ssh_keepalive
            ;;
        0)
            echo -e "\n${GREEN}退出脚本。${PLAIN}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}无效的输入，请输入 0-5 之间的数字。${PLAIN}"
            ;;
    esac

    # 暂停一下，让用户看清楚结果，按任意键回到菜单
    echo ""
    read -p "按回车键返回主菜单..."
done
