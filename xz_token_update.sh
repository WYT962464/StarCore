#!/bin/bash
# 小智MCP Token更新工具
# 用法: ./xz_token_update.sh <new_token>
# 或者: ./xz_token_update.sh (从剪贴板读取)
# 效果：更新iPhone上的token文件，proxy自动检测并重连

RELAY_URL="https://essays-commitment-commercial-gives.trycloudflare.com"

if [ -z "$1" ]; then
    echo "用法: $0 <new_token>"
    echo "  将新token写入iPhone的 /var/mobile/StarCore/xz_token.txt"
    echo "  proxy会自动检测文件变化并重连"
    exit 1
fi

TOKEN="$1"
echo "写入新token到iPhone..."

# 通过relay发送命令到iPhone
CMD_ID=$(curl -sk -X POST "${RELAY_URL}/command" \
    -H 'Content-Type: application/json' \
    -d "{\"action\":\"shell\",\"command\":\"echo '${TOKEN}' > /var/mobile/StarCore/xz_token.txt && echo TOKEN_UPDATED\"}" \
    2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))")

if [ -z "$CMD_ID" ]; then
    echo "❌ 发送命令失败"
    exit 1
fi

echo "命令ID: $CMD_ID, 等待执行..."

sleep 8

RESULT=$(curl -sk -X POST "${RELAY_URL}/check" \
    -H 'Content-Type: application/json' \
    -d "{\"id\":${CMD_ID}}" 2>/dev/null)

STATUS=$(echo "$RESULT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null)
STDOUT=$(echo "$RESULT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('stdout',''))" 2>/dev/null)

if [ "$STDOUT" = "TOKEN_UPDATED" ]; then
    echo "✅ Token已更新！proxy将在30秒内自动检测并重连"
else
    echo "⚠️ 状态: $STATUS, 输出: $STDOUT"
fi
