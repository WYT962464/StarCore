#!/bin/bash
# StarCore Tweak 部署脚本
# 通过 SSH 隧道部署到 iPhone

set -e

DEB_FILE="/home/ubuntu/starcore/deploy/StarCoreTweak.deb"
SSH_PORT=8028
IPHONE_USER="mobile"

echo "=== StarCore Tweak 部署脚本 ==="
echo ""

# 检查 .deb 文件
if [ ! -f "$DEB_FILE" ]; then
    echo "❌ .deb 文件不存在: $DEB_FILE"
    exit 1
fi

echo "📦 .deb 文件: $DEB_FILE"
echo "   大小: $(ls -lh $DEB_FILE | awk '{print $5}')"
echo ""

# 通过 SSH 隧道上传
echo "📤 上传到 iPhone..."
scp -P $SSH_PORT "$DEB_FILE" ${IPHONE_USER}@localhost:/tmp/StarCoreTweak.deb

echo "✅ 上传完成"
echo ""

# 通过 SSH 隧道安装
echo "📦 安装到 iPhone..."
ssh -p $SSH_PORT ${IPHONE_USER}@localhost << 'EOF'
    echo "正在安装 Tweak..."
    dpkg -i /tmp/StarCoreTweak.deb
    echo ""
    echo "✅ 安装完成"
    echo ""
    echo "重启 SpringBoard..."
    killall SpringBoard
    echo "✅ SpringBoard 已重启"
EOF

echo ""
echo "=== 部署完成 ==="
echo "请在 iPhone 上检查 Tweak 是否生效"
