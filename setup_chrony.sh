#!/bin/bash

# 设置时区为北京时间
echo "Setting timezone to Asia/Shanghai..."
rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Timezone set to Asia/Shanghai."

# 检查系统类型并安装 Chrony
if [ -f /etc/debian_version ]; then
    # Ubuntu/Debian 系统
    echo "Detected Ubuntu/Debian system."
    echo "Installing Chrony..."
    apt-get update
    apt-get install chrony -y

elif [ -f /etc/redhat-release ]; then
    # CentOS/RHEL 系统
    echo "Detected CentOS/RHEL system."
    echo "Installing Chrony..."
    yum install chrony -y
else
    echo "Unsupported system. Exiting."
    exit 1
fi

# 启用并启动 Chrony 服务
echo "Enabling and starting Chrony service..."
systemctl enable chrony
systemctl start chrony

# 验证时间同步
echo "Current system time:"
date

echo "Checking Chrony sync status..."
chronyc tracking

echo "Time synchronization setup complete!"