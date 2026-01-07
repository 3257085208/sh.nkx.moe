#!/bin/bash

# =========================================================
# NKX Network x 苏晨云 - VPS 专属初始化脚本 (完美对齐版)
# =========================================================

# --- 1. 样式与颜色定义 ---
# 字体颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 品牌墙样式 (核心修改：使用高亮白字+深色背景)
# \033[44;97m = 蓝底(44) + 亮白字(97)
STYLE_L='\033[44;97m' 
# \033[42;97m = 绿底(42) + 亮白字(97)
STYLE_R='\033[42;97m'
RESET='\033[0m'

# --- 2. 准备平铺内容 (严丝合缝对齐) ---
# 左边：NKXNetwork (10字符)，重复3次 = 30字符宽度
STR_L="NKXNetworkNKXNetworkNKXNetwork"
# 右边：苏晨云 (3汉字=6宽度)，重复5次 = 30字符宽度
STR_R="苏晨云苏晨云苏晨云苏晨云苏晨云"

# --- 3. 权限检查 ---
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请使用 root 用户运行此脚本！${PLAIN}" && exit 1

# --- 4. 视觉函数：品牌墙展示 ---
show_banner() {
    clear
    echo -e "${RESET}"
    
    # === 上半部分：密集色块墙 (6行) ===
    for i in {1..6}; do
        # 直接拼接左右两边，中间无空格，形成无缝墙体
        echo -e "${STYLE_L}${STR_L}${RESET}${STYLE_R}${STR_R}${RESET}"
    done
    
    # === 中间层：带文字的色块 (模拟 SPONSOR 标题) ===
    # 这里手动调整了空格，保证总宽度依然是左右各30
    echo -e "${STYLE_L}   NKX Network 官方控制台     ${RESET}${STYLE_R}      苏晨云 核心合作伙伴     ${RESET}"
    
    # === 下半部分：密集色块墙 (6行) ===
    for i in {1..6}; do
        echo -e "${STYLE_L}${STR_L}${RESET}${STYLE_R}${STR_R}${RESET}"
    done
    
    echo -e "${RESET}\n"
    echo -e " >> 欢迎使用 NKX Network 服务器初始化工具"
    echo -e " >> 当前时间: $(date "+%Y-%m-%d %H:%M:%S")"
    echo -e "===============================================================\n"
}

# --- 5. 功能模块 ---

# [功能1] 修改 Root 密码
func_password() {
    echo -e "${YELLOW}> [任务] 修改 Root 密码${PLAIN}"
    read -p "请输入新的密码: " MY_PASSWORD
    if [[ -n "$MY_PASSWORD" ]]; then
        echo "root:$MY_PASSWORD" | chpasswd
        echo -e "${GREEN}√ 密码修改成功！${PLAIN}"
    else
        echo -e "${RED}× 未输入密码，跳过。${PLAIN}"
    fi
}

# [功能2] 修改主机名
func_hostname() {
    echo -e "${YELLOW}> [任务] 修改主机名${PLAIN}"
    read -p "请输入新的主机名 (默认: nkx-node): " MY_HOSTNAME
    [[ -z "$MY_HOSTNAME" ]] && MY_HOSTNAME="nkx-node"
    
    hostnamectl set-hostname "$MY_HOSTNAME"
    # 修正 hosts 文件，防止重复堆叠
    sed -i '/127.0.0.1/d' /etc/hosts
    echo "127.0.0.1 localhost $MY_HOSTNAME" >> /etc/hosts
    echo -e "${GREEN}√ 主机名已设置为: $MY_HOSTNAME${PLAIN}"
}

# [功能3] 开启 BBR + FQ
func_bbr() {
    echo -e "${YELLOW}> [任务] 开启 BBR 加速${PLAIN}"
    if ! grep -q "net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.conf; then
        echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
        sysctl -p >/dev/null 2>&1
        echo -e "${GREEN}√ BBR 已成功开启！${PLAIN}"
    else
        echo -e "${GREEN}√ BBR 之前已开启，无需重复操作。${PLAIN}"
    fi
}

# [功能4] 系统基础优化 (时区+软件)
func_system_base() {
    echo -e "${YELLOW}> [任务] 系统环境优化 (时区 & 常用软件)${PLAIN}"
    
    # 1. 设置时区
    timedatectl set-timezone Asia/Shanghai
    echo -e "  - 时区设置为: Asia/Shanghai"
    
    # 2. 更新软件源并安装工具
    echo -e "  - 正在后台更新系统源并安装 curl, wget, vim, git... (请耐心等待)"
    
    # 设置非交互模式，防止 apt 弹窗询问
    export DEBIAN_FRONTEND=noninteractive
    
    if [ -f /etc/debian_version ]; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y curl wget vim git htop unzip tar screen >/dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        yum update -y >/dev/null 2>&1
        yum install -y curl wget vim git htop unzip tar screen >/dev/null 2>&1
    fi
    echo -e "${GREEN}√ 基础软件安装完成。${PLAIN}"
}

# [功能5] SSH 防掉线
func_ssh_keepalive() {
     echo -e "${YELLOW}> [任务] 配置 SSH 防掉线${PLAIN}"
     # 如果不存在配置则追加，存在则修改
     grep -q "^ClientAliveInterval" /etc/ssh/sshd_config && sed -i 's/^ClientAliveInterval.*/ClientAliveInterval 60/' /etc/ssh/sshd_config || echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
     grep -q "^ClientAliveCountMax" /etc/ssh/sshd_config && sed -i 's/^ClientAliveCountMax.*/ClientAliveCountMax 30/' /etc/ssh/sshd_config || echo "ClientAliveCountMax 30" >> /etc/ssh/sshd_config
     
     # 重启 SSH 服务
     service sshd restart 2>/dev/null || systemctl restart sshd
     echo -e "${GREEN}√ SSH 配置已优化 (心跳间隔 60s)。${PLAIN}"
}

# --- 6. 预设方案 (One-Click Setup) ---
func_preset_1() {
    echo -e "\n${YELLOW}=== 正在运行：预设方案 1 (全自动初始化) ===${PLAIN}"
    echo -e "包含：改名 + 改密 + 时区 + 软件更新 + BBR + SSH优化\n"
    
    # 统一询问环节
    read -p "1. 请输入新的主机名 (回车默认 nkx-node): " P_HOSTNAME
    [[ -z "$P_HOSTNAME" ]] && P_HOSTNAME="nkx-node"
    
    read -p "2. 请输入新的 Root 密码 (回车不修改): " P_PASSWORD
    
    echo -e "\n${GREEN}>>> 参数已确认，开始自动执行...${PLAIN}\n"
    
    # 1. 改名
    hostnamectl set-hostname "$P_HOSTNAME"
    sed -i '/127.0.0.1/d' /etc/hosts
    echo "127.0.0.1 localhost $P_HOSTNAME" >> /etc/hosts
    echo -e "${GREEN}[1/5] 主机名设置完成${PLAIN}"
    
    # 2. 改密
    if [[ -n "$P_PASSWORD" ]]; then
        echo "root:$P_PASSWORD" | chpasswd
        echo -e "${GREEN}[2/5] 密码修改完成${PLAIN}"
    else
        echo -e "${YELLOW}[2/5] 跳过密码修改${PLAIN}"
    fi
    
    # 3. 系统优化
    func_system_base
    echo -e "${GREEN}[3/5] 系统环境优化完成${PLAIN}"
    
    # 4. BBR
    func_bbr
    echo -e "${GREEN}[4/5] BBR 加速开启完成${PLAIN}"
    
    # 5. SSH
    func_ssh_keepalive
    echo -e "${GREEN}[5/5] SSH 防掉线配置完成${PLAIN}"
    
    echo -e "\n${GREEN}=========================================${PLAIN}"
    echo -e "${GREEN}   预设方案执行完毕！请重新登录 VPS。   ${PLAIN}"
    echo -e "${GREEN}=========================================${PLAIN}"
}

# --- 7. 主菜单逻辑 ---
while true; do
    show_banner
    echo -e "请选择操作："
    echo -e "${GREEN}1.${PLAIN} 修改 Root 密码"
    echo -e "${GREEN}2.${PLAIN} 修改主机名 (Hostname)"
    echo -e "${GREEN}3.${PLAIN} 一键开启 BBR + FQ"
    echo -e "${GREEN}4.${PLAIN} ${YELLOW}预设方案 1 (一键全能初始化)${PLAIN} ${RED}<- 推荐${PLAIN}"
    echo -e "${GREEN}5.${PLAIN} SSH 防掉线优化"
    echo -e "${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -p "请输入数字 [0-5]: " choice

    case "$choice" in
        1) func_password ;;
        2) func_hostname ;;
        3) func_bbr ;;
        4) func_preset_1 ;;
        5) func_ssh_keepalive ;;
        0) exit 0 ;;
        *) echo -e "\n${RED}无效输入，请重试。${PLAIN}" ;;
    esac

    # 暂停等待用户确认，非退出操作都暂停
    echo ""
    if [[ "$choice" != "0" ]]; then
        read -p "按回车键返回主菜单..."
    fi
done
