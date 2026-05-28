#!/bin/bash
#
# StarCore iOS 构建脚本
# 编译并生成 IPA 文件
#

set -e

echo "============================================================"
echo "🚀 StarCore iOS 构建脚本"
echo "============================================================"

# 项目路径
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
SCHEME="StarCore"
CONFIGURATION="Release"

# 清理
echo ""
echo "[1/6] 清理构建目录..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 检查 Xcode
echo ""
echo "[2/6] 检查 Xcode..."
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误：xcodebuild 未找到，请安装 Xcode"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n1)
echo "✅ ${XCODE_VERSION}"

# 构建
echo ""
echo "[3/6] 构建 StarCore..."
xcodebuild \
    -project StarCore.xcodeproj \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination 'generic/platform=iOS' \
    clean build \
    BUILD_DIR="${BUILD_DIR}" \
    SYMROOT="${BUILD_DIR}"

# 查找构建产物
echo ""
echo "[4/6] 查找构建产物..."
IPA_PATH=$(find "${BUILD_DIR}/Build/Products" -name "*.app" -type d | head -n1)

if [ -z "${IPA_PATH}" ]; then
    echo "❌ 错误：未找到 .app 文件"
    exit 1
fi

echo "✅ 找到: ${IPA_PATH}"

# 创建 IPA
echo ""
echo "[5/6] 创建 IPA 文件..."
IPA_FILE="${BUILD_DIR}/StarCore.ipa"

# 创建 Payload 目录
PAYLOAD_DIR="${BUILD_DIR}/Payload"
rm -rf "${PAYLOAD_DIR}"
mkdir -p "${PAYLOAD_DIR}"

# 复制 .app 到 Payload
cp -r "${IPA_PATH}" "${PAYLOAD_DIR}/StarCore.app"

# 创建 IPA
cd "${BUILD_DIR}"
zip -r "${IPA_FILE}" Payload

echo "✅ IPA 已创建: ${IPA_FILE}"

# 显示信息
echo ""
echo "[6/6] 构建信息"
echo "------------------------------------------------------------"
echo "📱 应用: StarCore"
echo "📦 IPA: ${IPA_FILE}"
echo "📊 大小: $(du -h "${IPA_FILE}" | cut -f1)"
echo "📅 时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "------------------------------------------------------------"

# 生成构建日志
BUILD_LOG="${BUILD_DIR}/build_log.txt"
echo "构建完成: $(date)" > "${BUILD_LOG}"
echo "IPA 路径: ${IPA_FILE}" >> "${BUILD_LOG}"

echo ""
echo "✅ 构建完成！"
echo ""
