#!/bin/bash
#
# StarCore iOS App 构建脚本
#

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
SCHEME="StarCore"

echo "=========================================="
echo "🚀 StarCore iOS App 构建"
echo "=========================================="

# 创建构建目录
mkdir -p "${BUILD_DIR}"

# 检查 xcodebuild
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ xcodebuild 未找到，请安装 Xcode"
    exit 1
fi

echo "📁 项目目录: ${PROJECT_DIR}"
echo "📦 构建目录: ${BUILD_DIR}"

# 构建
echo ""
echo "🔨 开始构建..."
xcodebuild \
    -project "${PROJECT_DIR}/StarCore.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${BUILD_DIR}/StarCore.xcarchive" \
    archive \
    2>&1 | tee "${BUILD_DIR}/build.log"

# 检查构建结果
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✅ 构建成功!"
    echo "📦 产物: ${BUILD_DIR}/StarCore.xcarchive"
else
    echo ""
    echo "❌ 构建失败"
    exit 1
fi
