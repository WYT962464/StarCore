#!/bin/bash
# StarCore iOS App 构建脚本
# 需要在 macOS + Xcode 环境下运行

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$PROJECT_DIR/build"
APP_NAME="StarCore"
BUNDLE_ID="com.starcore.app"
VERSION="1.0.0"

echo "🚀 StarCore iOS 构建脚本"
echo "================================"

# 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到 xcodebuild，请确保安装了 Xcode"
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

echo "📝 步骤 1: 清理构建"
xcodebuild clean -project "$PROJECT_DIR/StarCore.xcodeproj" -scheme "$APP_NAME" -configuration Release

echo "📝 步骤 2: 构建 Release 版本"
xcodebuild archive     -project "$PROJECT_DIR/StarCore.xcodeproj"     -scheme "$APP_NAME"     -configuration Release     -archivePath "$OUTPUT_DIR/$APP_NAME.xcarchive"     -destination "generic/platform=iOS"

echo "📝 步骤 3: 导出 IPA"
mkdir -p "$OUTPUT_DIR/ipa"

# 创建导出选项 plist
cat > "$OUTPUT_DIR/export_options.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive     -archivePath "$OUTPUT_DIR/$APP_NAME.xcarchive"     -exportOptionsPlist "$OUTPUT_DIR/export_options.plist"     -exportPath "$OUTPUT_DIR/ipa"

# 重命名 IPA
mv "$OUTPUT_DIR/ipa/$APP_NAME.ipa" "$OUTPUT_DIR/$APP_NAME-$VERSION.ipa" 2>/dev/null || true

echo ""
echo "✅ 构建完成!"
echo "📦 IPA 文件: $OUTPUT_DIR/$APP_NAME-$VERSION.ipa"
echo ""
echo "📋 下一步:"
echo "   1. 将 IPA 传输到 iPhone (通过 SSH 或 AirDrop)"
echo "   2. 使用 AltStore 或 Filza 安装"
echo "   3. 信任开发者证书"
echo "   4. 打开 App 验证"
echo ""
echo "🔗 SSH 传输命令:"
echo "   scp $OUTPUT_DIR/$APP_NAME-$VERSION.ipa mobile@<iPhone IP>:~/Downloads/"
echo ""
