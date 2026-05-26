
# 星核决策 API 端点

## 获取当前状态
GET /api/starcore/status

返回:
{
  "health": "warning|critical|healthy",
  "gravity_energy": 0.43,
  "dominant_gravity": "survival",
  "timestamp": "..."
}

## 获取决策上下文
GET /api/starcore/decision-context

返回:
{
  "motivation": {
    "dominant_gravity": "survival",
    "total_energy": 0.43,
    "recommendations": [...],
    "bias": {...}
  },
  "constraints": {
    "ethical_axioms": {...},
    "system_frozen": false
  }
}

## 评估行动
POST /api/starcore/evaluate
Body: {"description": "...", "priority": "P1"}

返回:
{
  "meta_rules_compliant": true,
  "recommendation": "approve|reject",
  "issues": [...]
}

## 订阅决策推送
WebSocket: ws://localhost:9090/starcore/decisions

实时推送星核自主决策结果。
