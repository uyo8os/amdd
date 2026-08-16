#!/bin/bash

# 设置路径
CRON_DIR="/etc/Cron"
LOG_DIR="/var/log/cron_tasks"
CRON_BACKUP="/tmp/current_crontab.bak"

# 确保目录存在并设置权限
mkdir -p "$CRON_DIR"
mkdir -p "$LOG_DIR"
chmod 755 "$CRON_DIR"
chmod 755 "$LOG_DIR"

# 同步北京时间
sync_time() {
    echo "正在同步北京时间..."
    if ! command -v ntpdate >/dev/null 2>&1; then
        echo "未检测到 ntpdate，正在尝试安装..."
        apt-get install -y ntpdate 2>/dev/null || yum install -y ntpdate
    fi
    ntpdate ntp.aliyun.com
    hwclock -w
}

# 显示当前时间和 Cron 状态
show_header() {
    clear
    echo "==================== 定时任务管理器 ===================="
    echo "当前系统时间：$(date +"%Y-%m-%d %H:%M:%S")"
    systemctl is-active cron >/dev/null 2>&1 && cron_status="运行中" || cron_status="未启动"
    echo "Cron 状态：$cron_status"
    echo "========================================================"
}

# 生成 cron 时间表达式
get_cron_time() {
    echo "请选择执行频率："
    echo "1) 每分钟执行"
    echo "2) 每小时执行"
    echo "3) 每3小时执行"
    echo "4) 每8小时执行"
    echo "5) 每16小时执行"
    echo "6) 每天0点执行"
    echo "7) 每天01点执行"
    echo "8) 每天02点执行"
    echo "9) 每天03点执行"
    echo "10) 每天04点执行"
    echo "11) 每天05点执行"
    echo "12) 每天06点执行"
    echo "13) 每天07点执行"
    echo "14) 每天08点执行"
    echo "15) 每天09点执行"
    echo "16) 每天10点执行"
    echo "17) 每天11点执行"
    echo "18) 每天12点执行"
    echo "19) 每天13点执行"
    echo "20) 每天13点执行"
    echo "21) 每天14点执行"
    echo "22) 每天15点执行"
    echo "23) 每天16点执行"
    echo "24) 每天17点执行"
    echo "25) 每天18点执行"
    echo "26) 每天19点执行"
    echo "27) 每天20点执行"
    echo "28) 每天21点执行"
    echo "29) 每天22点执行"
    echo "30) 每天23点执行"
    echo "31) 自定义 Cron 表达式"
    read -rp "输入序号 [1-31]: " choice

    case $choice in
        1) cron_expr="* * * * *" ;;
        2) cron_expr="0 * * * *" ;;
        3) cron_expr="0 */3 * * *" ;;
        4) cron_expr="0 */8 * * *" ;;
        5) cron_expr="0 */16 * * *" ;;
        6) cron_expr="0 0 * * *" ;;
        7) cron_expr="0 1 * * *" ;;
        8) cron_expr="0 2 * * *" ;;
        9) cron_expr="0 3 * * *" ;;
        10) cron_expr="0 4 * * *" ;;
        11) cron_expr="0 5 * * *" ;;
        12) cron_expr="0 6 * * *" ;;
        13) cron_expr="0 7 * * *" ;;
        14) cron_expr="0 8 * * *" ;;
        15) cron_expr="0 9 * * *" ;;
        16) cron_expr="0 10 * * *" ;;
        17) cron_expr="0 11 * * *" ;;
        18) cron_expr="0 12 * * *" ;;
        19) cron_expr="0 13 * * *" ;;
        20) cron_expr="0 13 * * *" ;;
        21) cron_expr="0 14 * * *" ;;
        22) cron_expr="0 15 * * *" ;;
        23) cron_expr="0 16 * * *" ;;
        24) cron_expr="0 17 * * *" ;;
        25) cron_expr="0 18 * * *" ;;
        26) cron_expr="0 19 * * *" ;;
        27) cron_expr="0 20 * * *" ;;
        28) cron_expr="0 21 * * *" ;;
        29) cron_expr="0 22 * * *" ;;
        30) cron_expr="0 23 * * *" ;;
        31) read -rp "请输入完整 Cron 表达式: " cron_expr ;;
        *) echo "无效选择"; return 1 ;;
    esac

    return 0
}

# 添加任务（支持任意命令或脚本）
add_task() {
    read -rp "请输入要执行的命令或脚本路径（例如 systemctl restart V2bX.service 或 /root/csv2.sh）: " cmd

    echo "任务名称设置："
    echo "1) 自动生成任务名"
    echo "2) 手动输入任务名（仅英文/数字/下划线/中划线，无空格）"
    read -rp "请输入选项 [1-2]: " name_mode

    if [[ "$name_mode" == "2" ]]; then
        while true; do
            read -rp "请输入任务名称: " service_name
            if [[ "$service_name" =~ ^[A-Za-z0-9_-]+$ ]]; then
                break
            fi
            echo "⚠️ 任务名称无效：只能包含英文、数字、下划线或中划线，且不能有空格"
        done
    else
        if [[ "$cmd" =~ ^systemctl[[:space:]]+(start|stop|restart|reload|status)[[:space:]]+([^.[:space:]]+) ]]; then
            action="${BASH_REMATCH[1]}"
            unit_name="${BASH_REMATCH[2]}"
            service_name="${unit_name}_${action}"
        else
            cmd_main="${cmd%% *}"
            service_name=$(basename "$cmd_main")
        fi
        service_name="${service_name%.service}"
    fi

    base_service_name="$service_name"
    suffix=2
    while [[ -f "$CRON_DIR/$service_name" || -f "$LOG_DIR/task_${service_name}.log" ]]; do
        service_name="${base_service_name}_${suffix}"
        ((suffix++))
    done
    if [[ "$service_name" != "$base_service_name" ]]; then
        echo "⚠️ 检测到同名任务，已自动重命名为：$service_name"
    fi

    script_path="$CRON_DIR/$service_name"
    log_path="$LOG_DIR/task_${service_name}.log"

    get_cron_time || return

    cat > "$script_path" <<EOF
#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

echo "----------------------------------------------------------------------------"
echo "→ 正在执行：$cmd"
$cmd
if [ \$? -eq 0 ]; then
    echo "★[\$(date +"%Y-%m-%d %H:%M:%S")] ✅ 执行成功"
else
    echo "★[\$(date +"%Y-%m-%d %H:%M:%S")] ❌ 执行失败"
fi
echo "----------------------------------------------------------------------------"
EOF

    chmod 755 "$script_path"
    touch "$log_path"
    chmod 644 "$log_path"

    crontab -l 2>/dev/null > "$CRON_BACKUP"
    echo "$cron_expr $script_path >> $log_path 2>&1" >> "$CRON_BACKUP"
    crontab "$CRON_BACKUP"

    systemctl restart cron
    echo "✅ 任务添加成功！"
}

# 删除任务
delete_task() {
    echo "当前任务列表："
    ls "$CRON_DIR"
    echo
    read -rp "请输入要删除的任务名称（如 V2bX 或 csv2.sh，输入 0 取消）: " name

    if [[ -z "$name" || "$name" == "0" ]]; then
        echo "❎ 已取消删除任务"
        return
    fi

    script_path="$CRON_DIR/$name"
    log_path="$LOG_DIR/task_${name}.log"

    if [[ ! -f "$script_path" ]]; then
        echo "⚠️ 找不到指定的任务脚本：$script_path"
        return
    fi

    crontab -l 2>/dev/null | grep -v "$script_path" > "$CRON_BACKUP"
    crontab "$CRON_BACKUP"

    rm -f "$script_path"
    rm -f "$log_path"
    systemctl restart cron
    echo "✅ 任务 [$name] 已删除并重载 Cron"
}

# 查看任务
view_tasks() {
    echo "当前任务列表："
    crontab -l | grep "$CRON_DIR" || echo "无任务"

    echo
    echo "可用日志："
    ls -1 "$LOG_DIR"

    read -rp "是否查看某个日志内容？输入日志文件名（或回车跳过）: " logname
    if [[ -n "$logname" ]] && [[ -f "$LOG_DIR/$logname" ]]; then
        echo "========== 日志内容 =========="
        tail -n 30 "$LOG_DIR/$logname"
        echo "=============================="
    fi
}

# 主菜单
main_menu() {
    while true; do
        show_header
        echo "1) 添加定时任务"
        echo "2) 删除定时任务"
        echo "3) 查看任务和日志"
        echo "0) 退出脚本"
        echo "--------------------------------------------------------"
        read -rp "请输入选项: " option
        case "$option" in
            1) add_task ;;
            2) delete_task ;;
            3) view_tasks ;;
            0) echo "再见！"; exit 0 ;;
            *) echo "无效选项，请重试。" ;;
        esac
        read -rp "按 Enter 返回菜单..."
    done
}

# 启动脚本
sync_time
main_menu
