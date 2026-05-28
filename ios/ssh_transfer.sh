#!/bin/bash
#
# StarCore SSH 传输脚本
# 将 IPA 和 Tweak 文件传输到 iPhone
#

set -e

echo "============================================================"
echo "📡 StarCore SSH 传输脚本"
echo "============================================================"

# 配置
SERVER_HOST="124.222.29.75"
SERVER_USER="ubuntu"
SERVER_PORT="8028"
IPHONE_TUNNEL_IP="10.70.92.235"
IPHONE_SSH_PORT="22"
IPHONE_USER="mobile"
IPHONE_PASSWORD="962464"

# 文件路径
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
IPA_FILE="${BUILD_DIR}/StarCore.ipa"
TWEAK_DIR="${PROJECT_DIR}/tweak"

# 检查文件
echo ""
echo "[1/4] 检查文件..."

if [ ! -f "${IPA_FILE}" ]; then
    echo "❌ 错误：IPA 文件未找到: ${IPA_FILE}"
    echo "   请先运行 build.sh 构建 IPA"
    exit 1
fi

echo "✅ IPA: ${IPA_FILE} ($(du -h "${IPA_FILE}" | cut -f1))"

# 传输 IPA 到服务器
echo ""
echo "[2/4] 传输到服务器..."
scp -P ${SERVER_PORT} \
    "${IPA_FILE}" \
    "${SERVER_USER}@${SERVER_HOST}:~/starcore/ios/"

echo "✅ IPA 已传输到服务器"

# 通过 SSH 隧道传输到 iPhone
echo ""
echo "[3/4] 通过隧道传输到 iPhone..."
ssh -p ${SERVER_PORT} \
    -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=30 \
    ${SERVER_USER}@${SERVER_HOST} \
    "scp -P ${IPHONE_SSH_PORT} \
        ~/starcore/ios/StarCore.ipa \
        ${IPHONE_USER}@${IPHONE_TUNNEL_IP}:/tmp/"

echo "✅ IPA 已传输到 iPhone (/tmp/StarCore.ipa)"

# 传输 Tweak 文件（如果有）
if [ -d "${TWEAK_DIR}" ]; then
    echo ""
    echo "[4/4] 传输 Tweak 文件..."
    
    # 传输到服务器
    scp -P ${SERVER_PORT} \
        -r "${TWEAK_DIR}" \
        "${SERVER_USER}@${SERVER_HOST}:~/starcore/tweak/"
    
    # 通过隧道传输到 iPhone
    ssh -p ${SERVER_PORT} \
        -o StrictHostKeyChecking=no \
        ${SERVER_USER}@${SERVER_HOST} \
        "scp -P ${IPHONE_SSH_PORT} -r \
            ~/starcore/tweak/ \
            ${IPHONE_USER}@${IPHONE_TUNNEL_IP}:/tmp/"
    
    echo "✅ Tweak 文件已传输"
else
    echo "[4/4] 跳过 Tweak 传输（目录不存在）"
fi

echo ""
echo "============================================================"
echo "✅ 传输完成！"
echo "============================================================"
echo ""
echo "📱 iPhone 文件位置:"
echo "   IPA: /tmp/StarCore.ipa"
echo "   Tweak: /tmp/tweak/"
echo ""
echo "📋 下一步:"
echo "   1. 在 iPhone 上使用 Filza 安装 IPA"
echo "   2. 安装 Tweak 到 /var/jb/usr/lib/TweakInject/"
echo "   3. 重启 SpringBoard"
echo ""
