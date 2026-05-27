#!/bin/bash
# SSH 传输脚本 - 将 IPA 从服务器传输到 iPhone

set -e

SERVER_IP="124.222.29.75"
IPHONE_IP="192.168.1.100"
IPHONE_USER="mobile"
IPHONE_PASSWORD="[REDACTED]"
IPA_PATH="/home/ubuntu/starcore/ios/build/StarCore-1.0.0.ipa"
TUNNEL_PORT="8028"

echo "🚀 SSH 传输脚本"
echo "================================"

# 检查 IPA 是否存在
if [ ! -f "$IPA_PATH" ]; then
    echo "❌ 错误: IPA 文件不存在: $IPA_PATH"
    echo "   请先运行构建脚本"
    exit 1
fi

echo "📝 步骤 1: 检查 SSH 隧道"
if ! nc -z localhost $TUNNEL_PORT 2>/dev/null; then
    echo "   ⚠️ 隧道未建立，尝试建立..."
    ssh -f -N -L $TUNNEL_PORT:localhost:22 $IPHONE_USER@$IPHONE_IP -p 8022
    sleep 2
fi

echo "📝 步骤 2: 传输 IPA 到 iPhone"
scp -P $TUNNEL_PORT "$IPA_PATH" $IPHONE_USER@localhost:~/Downloads/

echo "📝 步骤 3: 验证传输"
ssh -p $TUNNEL_PORT $IPHONE_USER@localhost "ls -la ~/Downloads/*.ipa"

echo ""
echo "✅ 传输完成!"
echo "📦 IPA 已保存到 iPhone: ~/Downloads/StarCore-1.0.0.ipa"
echo ""
echo "📋 下一步:"
echo "   1. 在 iPhone 上打开 Filza"
echo "   2. 导航到 ~/Downloads/"
echo "   3. 点击 IPA 文件"
echo "   4. 选择 'Install'"
echo "   5. 打开 StarCore App 验证"
echo ""
