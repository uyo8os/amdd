#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 检查是否为 root 用户
[[ $EUID -ne 0 ]] && echo -e "${RED}错误：${PLAIN} 必须使用 root 用户运行此脚本！\n" && exit 1

# 配置文件路径
GAI_CONF="/etc/gai.conf"
SYSCTL_CONF="/etc/sysctl.conf"

# 功能 1: 优先使用 IPv4
function set_ipv4_priority() {
    echo -e "${YELLOW}正在设置 IPv4 优先...${PLAIN}"
    
    # 如果文件不存在，创建它
    if [ ! -f "$GAI_CONF" ]; then
        touch "$GAI_CONF"
    fi

    # 检查是否已经设置了
    if grep -q "^precedence ::ffff:0:0/96 100" "$GAI_CONF"; then
        echo -e "${GREEN}检测到已经设置了 IPv4 优先，无需更改。${PLAIN}"
    else
        # 这一行配置会让系统更偏向于使用 IPv4 (IPv4-mapped IPv6 addresses)
        echo "precedence ::ffff:0:0/96 100" >> "$GAI_CONF"
        echo -e "${GREEN}设置完成！IPv4 现在拥有更高优先级。${PLAIN}"
    fi
}

# 功能 2: 优先使用 IPv6
function set_ipv6_priority() {
    echo -e "${YELLOW}正在设置 IPv6 优先...${PLAIN}"
    
    # 默认情况下 Linux 倾向于 IPv6。
    # 我们需要移除强制 IPv4 优先的配置 (precedence ::ffff:0:0/96 100)
    # 同时可以显式添加 IPv6 优先的规则（通常默认就是，所以主要是清理 IPv4 优先的规则）
    
    if [ -f "$GAI_CONF" ]; then
        # 删除可能存在的 IPv4 优先配置
        sed -i '/^precedence ::ffff:0:0\/96 100/d' "$GAI_CONF"
        
        # 可选：确保 label 2002 (6to4) 优先级较低，通常默认配置不需要动
        echo -e "${GREEN}设置完成！已移除 IPv4 优先配置，系统将默认优先使用 IPv6。${PLAIN}"
    else
        echo -e "${GREEN}配置文件不存在，系统默认即为 IPv6 优先。${PLAIN}"
    fi
}

# 功能 3: 还原默认配置
function restore_priority() {
    echo -e "${YELLOW}正在还原网络优先级默认配置...${PLAIN}"
    
    # 还原就是把我们在 gai.conf 里做的修改去掉
    # 如果用户之前的 gai.conf 很复杂，直接删除我们添加的行是最安全的
    
    if [ -f "$GAI_CONF" ]; then
        sed -i '/^precedence ::ffff:0:0\/96 100/d' "$GAI_CONF"
        echo -e "${GREEN}已还原默认配置（移除了自定义的 IPv4 优先规则）。${PLAIN}"
    else
        echo -e "${GREEN}配置文件不存在，无需还原。${PLAIN}"
    fi
}

# 功能 4: 禁用 IPv6
function disable_ipv6() {
    echo -e "${YELLOW}正在禁用 IPv6...${PLAIN}"
    
    # 检查是否已经存在相关配置，先删除旧的以防重复
    sed -i '/^net.ipv6.conf.all.disable_ipv6/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv6.conf.default.disable_ipv6/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv6.conf.lo.disable_ipv6/d' "$SYSCTL_CONF"
    
    # 添加禁用配置
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> "$SYSCTL_CONF"
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> "$SYSCTL_CONF"
    echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> "$SYSCTL_CONF"
    
    # 应用更改
    sysctl -p >/dev/null 2>&1
    
    echo -e "${GREEN}IPv6 已禁用！${PLAIN}"
}

# 功能 5: 启用 IPv6
function enable_ipv6() {
    echo -e "${YELLOW}正在启用 IPv6...${PLAIN}"
    
    # 1. 修改配置文件
    # 先删除可能存在的禁用配置
    sed -i '/^net.ipv6.conf.all.disable_ipv6/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv6.conf.default.disable_ipv6/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv6.conf.lo.disable_ipv6/d' "$SYSCTL_CONF"
    
    # 显式开启 (设为 0)
    echo "net.ipv6.conf.all.disable_ipv6 = 0" >> "$SYSCTL_CONF"
    echo "net.ipv6.conf.default.disable_ipv6 = 0" >> "$SYSCTL_CONF"
    echo "net.ipv6.conf.lo.disable_ipv6 = 0" >> "$SYSCTL_CONF"
    
    # 2. 应用更改到内核
    sysctl -p >/dev/null 2>&1
    
    # 3. 强制对所有当前接口启用 IPv6 (解决 sysctl -p 可能不覆盖特定接口的问题)
    # 获取所有网络接口名称 (排除 lo)
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")
    for iface in $interfaces; do
        sysctl -w net.ipv6.conf."$iface".disable_ipv6=0 >/dev/null 2>&1
    done
    
    echo -e "${GREEN}IPv6 配置已启用。${PLAIN}"
    echo -e "${YELLOW}正在尝试重启网络服务以重新获取 IPv6 地址...${PLAIN}"
    
    # 4. 尝试重启网络服务
    # 检测并重启常见的网络服务
    if systemctl is-active --quiet networking; then
        systemctl restart networking
        echo -e "${GREEN}networking 服务已重启。${PLAIN}"
    elif systemctl is-active --quiet systemd-networkd; then
        systemctl restart systemd-networkd
        echo -e "${GREEN}systemd-networkd 服务已重启。${PLAIN}"
    elif systemctl is-active --quiet NetworkManager; then
        systemctl restart NetworkManager
        echo -e "${GREEN}NetworkManager 服务已重启。${PLAIN}"
    else
        echo -e "${YELLOW}未检测到常用的网络管理服务(networking/systemd-networkd/NetworkManager)。${PLAIN}"
        echo -e "${YELLOW}如果 IPv6 仍未生效，请尝试重启服务器: reboot${PLAIN}"
    fi
    
    echo -e "${GREEN}操作完成！请测试：curl ip.sb -6${PLAIN}"
}

# 主菜单
function show_menu() {
    clear
    echo -e "============================================"
    echo -e " IPv6 管理脚本 (Debian/Ubuntu) "
    echo -e "============================================"
    echo -e " 1. 优先使用 IPv4 访问网络"
    echo -e " 2. 优先使用 IPv6 访问网络"
    echo -e " 3. 还原 网络优先(IPv4/IPv6) 为默认配置"
    echo -e " 4. 禁用 IPv6"
    echo -e " 5. 启用 IPv6 (禁用 IPv6 后恢复)"
    echo -e " 0. 退出脚本"
    echo -e "============================================"
    echo -e ""
    read -p " 请输入选项 [0-5]: " num
    
    case "$num" in
        1)
            set_ipv4_priority
            ;;
        2)
            set_ipv6_priority
            ;;
        3)
            restore_priority
            ;;
        4)
            disable_ipv6
            ;;
        5)
            enable_ipv6
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}请输入正确的数字 [0-5]${PLAIN}"
            ;;
    esac
}

# 运行菜单
show_menu
