#!/bin/bash
# ========================================
# 星核 App v2.0 部署脚本
# 用于 Dopamine rootless 越狱 iPhone X
# ========================================

set -e

PHONE_IP="${1:-localhost}"
PHONE_USER="root"
THEOS_PATH="/var/jb/var/mobile/theos"
AGENT_DIR="/var/mobile/StarCoreAgent"
APP_SRC_DIR="/var/mobile/StarCoreApp"
PYTHON="/var/jb/usr/local/bin/python3.12"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[星核部署]${NC} $1"; }
ok() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# SSH/SCP helper
ssh_cmd() { ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${PHONE_USER}@${PHONE_IP}" "$@"; }
scp_to() { scp -o StrictHostKeyChecking=no "$1" "${PHONE_USER}@${PHONE_IP}:$2"; }

# ========================================
# Step 1: 传输 starcore-agent-v2.py
# ========================================
log "Step 1: 传输星核 Agent v2.0..."

AGENT_LOCAL="./StarCoreAgent/starcore-agent-v2.py"
if [ ! -f "$AGENT_LOCAL" ]; then
    err "找不到 ${AGENT_LOCAL}"
fi

# 在手机上创建目录
ssh_cmd "mkdir -p ${AGENT_DIR}"

# Base64 编码传输（避免特殊字符问题）
log "  使用 base64 编码传输..."
base64 "$AGENT_LOCAL" | ssh_cmd "base64 -d > ${AGENT_DIR}/starcore-agent.py"
ok "Agent 传输完成"

# ========================================
# Step 2: 传输 Theos App 项目文件
# ========================================
log "Step 2: 传输 Theos App 项目文件..."

ssh_cmd "mkdir -p ${APP_SRC_DIR}"

APP_FILES=(
    "Makefile"
    "main.m"
    "StarCoreAppDelegate.h"
    "StarCoreAppDelegate.m"
    "StarCoreViewController.h"
    "StarCoreViewController.m"
    "Info.plist"
)

for f in "${APP_FILES[@]}"; do
    LOCAL_PATH="./StarCoreApp/$f"
    if [ -f "$LOCAL_PATH" ]; then
        scp_to "$LOCAL_PATH" "${APP_SRC_DIR}/$f"
        log "  已传输: $f"
    else
        warn "  文件不存在: $LOCAL_PATH"
    fi
done

# 传输 LaunchScreen.storyboard 到 resources 子目录
ssh_cmd "mkdir -p ${APP_SRC_DIR}/resources"
scp_to "./StarCoreApp/resources/LaunchScreen.storyboard" "${APP_SRC_DIR}/resources/LaunchScreen.storyboard"
ok "App 项目文件传输完成"

# ========================================
# Step 3: 在手机上编译 Theos App
# ========================================
log "Step 3: 在手机上编译 StarCoreApp (fat binary: arm64+arm64e)..."

# 设置 Theos 环境变量并编译
ssh_cmd "cd ${APP_SRC_DIR} && export THEOS=${THEOS_PATH} && make clean && make" \
    || err "编译失败！请检查 Theos 环境和源码"

ok "App 编译成功"

# ========================================
# Step 4: 安装 App（全能签方式）
# ========================================
log "Step 4: 安装 App..."

# Theos 编译产物路径
APP_BUILT="${APP_SRC_DIR}/.theos/obj/debug/StarCoreApp.app"

# 检查编译产物
ssh_cmd "test -d ${APP_BUILT}" || err "找不到编译产物: ${APP_BUILT}"

# 创建全能签可识别的目录
# 全能签通常从 /var/mobile/Documents 或 IPA 方式安装
# 这里先复制到可访问位置，再用全能签导入
INSTALL_STAGING="/var/mobile/Documents/StarCoreApp_staging"
ssh_cmd "rm -rf ${INSTALL_STAGING}"
ssh_cmd "cp -r ${APP_BUILT} ${INSTALL_STAGING}/StarCoreApp.app"
ssh_cmd "chmod -R 755 ${INSTALL_STAGING}/StarCoreApp.app"

# 生成 IPA 文件（全能签可以导入 IPA）
ssh_cmd "cd ${INSTALL_STAGING} && mkdir -p Payload && cp -r StarCoreApp.app Payload/ && zip -r /var/mobile/Documents/StarCoreApp.ipa Payload/ && rm -rf Payload"

ok "IPA 已生成: /var/mobile/Documents/StarCoreApp.ipa"
warn "请使用全能签导入 IPA: /var/mobile/Documents/StarCoreApp.ipa"

# ========================================
# Step 5: 重启 Agent 进程
# ========================================
log "Step 5: 重启星核 Agent..."

# Kill 旧进程
ssh_cmd "pkill -f starcore-agent.py 2>/dev/null || true"
sleep 1

# 启动新 Agent（后台运行）
ssh_cmd "nohup ${PYTHON} ${AGENT_DIR}/starcore-agent.py > ${AGENT_DIR}/agent.log 2>&1 &"
sleep 2

# 验证启动
if ssh_cmd "pgrep -f starcore-agent.py > /dev/null 2>&1"; then
    ok "星核 Agent v2.0 已启动 (PID: $(ssh_cmd 'pgrep -f starcore-agent.py | head -1'))"
else
    warn "Agent 可能未启动成功，检查日志: ${AGENT_DIR}/agent.log"
fi

# ========================================
# 完成
# ========================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✦ 星核 App v2.0 部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  📱 Agent: http://localhost:${AGENT_PORT:-8643}"
echo -e "  📦 IPA:   /var/mobile/Documents/StarCoreApp.ipa"
echo -e "  📋 日志:  ${AGENT_DIR}/agent.log"
echo ""
echo -e "  ${YELLOW}下一步:${NC}"
echo -e "  1. 打开全能签 → 导入 IPA → 安装"
echo -e "  2. 主屏找到 '✦ 星核' 图标启动"
echo -e "  3. 或直接 Safari 访问 http://localhost:8643"
echo ""
