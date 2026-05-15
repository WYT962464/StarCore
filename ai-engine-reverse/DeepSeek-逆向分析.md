# DeepSeek App 逆向分析

## 基本信息
- Bundle ID: com.deepseek.mobile (推测)
- 架构: arm64 Mach-O
- 语言: Swift (主模块 DeepSeek_Chat)
- 网络库: Alamofire
- 存储: MMKV + WCDB
- 认证: Cookie-based

## API端点 (chat.deepseek.com)

### 核心聊天API
- `POST /api/v0/chat/completion` — 发送消息，SSE流式返回
- `POST /api/v0/chat/continue` — 继续生成
- `POST /api/v0/chat/regenerate` — 重新生成
- `POST /api/v0/chat/edit_message` — 编辑消息
- `POST /api/v0/chat/stop_stream` — 停止流式输出
- `POST /api/v0/chat/resume_stream` — 恢复流式输出
- `GET  /api/v0/chat/history_messages` — 获取历史消息
- `GET  /api/v0/chat/get_client_streams` — 获取客户端流

### 会话管理
- `POST /api/v0/chat_session/create` — 创建新会话
- `POST /api/v0/chat_session/delete` — 删除会话
- `GET  /api/v0/chat_session/fetch_page` — 获取会话列表
- `POST /api/v0/chat_session/update_title` — 更新会话标题
- `POST /api/v0/chat_session/update_pinned` — 置顶会话

### 认证
- `POST /api/v0/users/login` — 登录
- `POST /api/v0/users/register` — 注册
- `POST /api/v0/users/one_tap_login` — 一键登录
- `GET  /api/v0/users/current` — 获取当前用户

### 访客模式 (免费！)
- `GET  /api/v0/guest/available` — 检查访客模式是否可用
- `POST /api/v0/guest/chat/completion` — 访客聊天(免费！)
- `POST /api/v0/users/create_guest_challenge` — 创建访客挑战

### PoW (Proof of Work) 防滥用
- `POST /api/v0/chat/create_pow_challenge` — 创建PoW挑战
- 请求头: `X-DS-PoW-Response` — 登录用户的PoW响应
- 请求头: `X-DS-Guest-PoW-Response` — 访客的PoW响应
- 类: Challenge, ChallengeAlgorithm, ChallengeResponse
- 方法: fetchPow(api:retry:)

## 关键类 (Swift)

### UI层
- `DeepSeek_Chat.MessageViewController` — 聊天页面
- `DeepSeek_Chat.MessageListView` — 消息列表
- `DeepSeek_Chat.InputAreaContainerView` — 输入区域
- `DeepSeek_Chat.SendButton` — 发送按钮
- `DeepSeek_Chat.SessionListViewController` — 会话列表

### 数据层
- `ChatCompletion` — 聊天完成模型
- `ChatOperation` / `ChatOperationContext` / `ChatOperationDelegate` — 聊天操作
- `ChatState` / `ChatStatus` — 聊天状态
- `ChatResumeStream` — 恢复流
- `ChatHistoryMessages` — 历史消息
- `GuestContext` / `GuestApi` — 访客模式

### PoW
- `Challenge` / `ChallengeAlgorithm` / `ChallengeResponse`
- `Base64ChallengeJson`
- `authed_pow_functions` — 已认证用户的PoW函数

## 认证机制
- **Cookie-based**: App使用Cookie认证（非Bearer token）
- 关键Cookie名: 待抓包确认（可能是 `chatdse` 或类似）
- 登录后Cookie自动管理

## 访客模式（重点！）
DeepSeek有**访客模式**，不需要登录即可使用！
- `GuestApi` — 访客API客户端
- `GuestContext` — 访客上下文
- `/api/v0/guest/chat/completion` — 访客聊天端点
- 访客需要通过PoW挑战验证
- 请求头 `X-DS-Guest-PoW-Response`

## 利用方案

### 方案1: 直接调API（最简单）
1. 在DeepSeek App登录，抓包获取Cookie
2. 解PoW挑战（逆向ChallengeAlgorithm）
3. 星核App直接POST到 `/api/v0/chat/completion`
4. SSE流式接收回复

### 方案2: 访客模式（无需账号！）
1. 调 `/api/v0/guest/available` 检查可用性
2. 调 `/api/v0/users/create_guest_challenge` 获取挑战
3. 逆向 `ChallengeAlgorithm` 解PoW
4. 带 `X-DS-Guest-PoW-Response` 请求头调 `/api/v0/guest/chat/completion`
5. SSE流式接收

### 方案3: Hook注入（最稳）
1. Tweak注入DeepSeek App进程
2. Hook Alamofire的streamRequest方法
3. 拦截请求和响应，转发给星核App
4. Cookie/PoW全由DeepSeek App自己处理
