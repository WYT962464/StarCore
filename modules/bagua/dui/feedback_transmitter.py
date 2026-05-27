"""
兑 ☱ 反馈回传器 (Feedback Transmitter)
========================================
八卦之八，悦，代表反馈与交互能力。

功能：
- 用户反馈收集
- 交互记录
- 反馈分析
- 回传机制

卦象：兑 ☱ (011) - 泽，悦
属性：悦、喜悦、交流、反馈
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, asdict
from enum import Enum
import threading


class FeedbackType(Enum):
    """反馈类型"""
    POSITIVE = "positive"       # 正面
    NEGATIVE = "negative"       # 负面
    NEUTRAL = "neutral"         # 中性
    QUESTION = "question"       # 问题
    SUGGESTION = "suggestion"   # 建议


class FeedbackSource(Enum):
    """反馈来源"""
    USER = "user"               # 用户
    SYSTEM = "system"           # 系统
    EXTERNAL = "external"       # 外部
    AUTO = "auto"               # 自动检测


@dataclass
class FeedbackRecord:
    """反馈记录"""
    id: str
    type: FeedbackType
    source: FeedbackSource
    content: str
    context: Dict[str, Any]
    timestamp: str
    processed: bool = False
    response: Optional[str] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


@dataclass
class FeedbackAnalysis:
    """反馈分析"""
    total_count: int
    type_distribution: Dict[str, int]
    sentiment_score: float  # -1 到 1
    top_keywords: List[str]
    trends: Dict[str, Any]


class FeedbackTransmitter:
    """兑反馈回传器"""
    
    def __init__(self, name: str = "DUI"):
        self.name = name
        self.binary = "011"  # 兑卦二进制
        
        # 存储路径
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/dui_feedback")
        self.base_path.mkdir(parents=True, exist_ok=True)
        self.feedback_log_path = self.base_path / "feedback_log.jsonl"
        self.analysis_path = self.base_path / "analysis.json"
        
        # 反馈记录
        self.feedback_history: List[FeedbackRecord] = []
        self.pending_feedback: List[FeedbackRecord] = []
        self.lock = threading.Lock()
        
        # 反馈处理器
        self.processors: List[Callable] = []
        
        # 统计
        self.feedback_count = 0
        self.processed_count = 0
        
        # 情感分析缓存
        self._sentiment_cache: Dict[str, float] = {}
    
    def submit_feedback(self, content: str, feedback_type: FeedbackType = FeedbackType.NEUTRAL,
                       source: FeedbackSource = FeedbackSource.USER,
                       context: Optional[Dict[str, Any]] = None) -> FeedbackRecord:
        """
        提交反馈
        
        Args:
            content: 反馈内容
            feedback_type: 反馈类型
            source: 来源
            context: 上下文
            
        Returns:
            反馈记录
        """
        feedback_id = f"feedback_{datetime.now().strftime('%Y%m%d%H%M%S')}_{len(self.feedback_history)}"
        
        record = FeedbackRecord(
            id=feedback_id,
            type=feedback_type,
            source=source,
            content=content,
            context=context or {},
            timestamp=datetime.now().isoformat()
        )
        
        # 添加到历史
        with self.lock:
            self.feedback_history.append(record)
            self.pending_feedback.append(record)
        
        self.feedback_count += 1
        
        # 记录日志
        self._log_feedback(record)
        
        # 触发处理器
        self._process_feedback(record)
        
        return record
    
    def register_processor(self, processor: Callable) -> None:
        """注册反馈处理器"""
        self.processors.append(processor)
    
    def get_pending_feedback(self) -> List[FeedbackRecord]:
        """获取待处理反馈"""
        with self.lock:
            return list(self.pending_feedback)
    
    def process_feedback(self, feedback_id: str, response: Optional[str] = None) -> bool:
        """
        处理反馈
        
        Args:
            feedback_id: 反馈 ID
            response: 响应内容
            
        Returns:
            是否成功
        """
        with self.lock:
            for record in self.pending_feedback:
                if record.id == feedback_id:
                    record.processed = True
                    record.response = response
                    self.pending_feedback.remove(record)
                    self.processed_count += 1
                    return True
        
        return False
    
    def analyze_feedback(self, limit: int = 100) -> FeedbackAnalysis:
        """
        分析反馈
        
        Args:
            limit: 分析数量限制
            
        Returns:
            分析结果
        """
        # 获取反馈
        with self.lock:
            feedbacks = self.feedback_history[-limit:]
        
        # 类型分布
        type_dist = {}
        for ft in FeedbackType:
            type_dist[ft.value] = sum(1 for f in feedbacks if f.type == ft)
        
        # 情感分数（简化版）
        sentiment_scores = []
        for record in feedbacks:
            score = self._analyze_sentiment(record.content)
            sentiment_scores.append(score)
        
        avg_sentiment = sum(sentiment_scores) / len(sentiment_scores) if sentiment_scores else 0
        
        # 关键词（简化版）
        keywords = self._extract_keywords(feedbacks)
        
        # 趋势
        trends = self._analyze_trends(feedbacks)
        
        return FeedbackAnalysis(
            total_count=len(feedbacks),
            type_distribution=type_dist,
            sentiment_score=round(avg_sentiment, 3),
            top_keywords=keywords[:10],
            trends=trends
        )
    
    def get_feedback_stats(self) -> Dict[str, Any]:
        """获取反馈统计"""
        return {
            "name": self.name,
            "binary": self.binary,
            "total_feedback": self.feedback_count,
            "pending_feedback": len(self.pending_feedback),
            "processed_feedback": self.processed_count,
            "recent_feedback": [
                {
                    "id": f.id,
                    "type": f.type.value,
                    "timestamp": f.timestamp
                }
                for f in self.feedback_history[-5:]
            ]
        }
    
    def clear_pending(self) -> int:
        """清除待处理反馈"""
        with self.lock:
            count = len(self.pending_feedback)
            self.pending_feedback = []
        return count
    
    def _process_feedback(self, record: FeedbackRecord) -> None:
        """处理反馈"""
        for processor in self.processors:
            try:
                processor(record)
            except:
                pass
    
    def _analyze_sentiment(self, text: str) -> float:
        """分析情感（简化版）"""
        # 这里可以集成真实的情感分析
        # 简化：基于关键词
        positive_words = ["好", "棒", "喜欢", "满意", "感谢", "谢谢", "great", "good", "love"]
        negative_words = ["差", "坏", "失望", "不喜欢", "糟糕", "bad", "hate", "terrible"]
        
        score = 0
        text_lower = text.lower()
        
        for word in positive_words:
            if word in text_lower:
                score += 1
        
        for word in negative_words:
            if word in text_lower:
                score -= 1
        
        # 归一化到 -1 到 1
        if score > 0:
            return min(score / 5, 1.0)
        elif score < 0:
            return max(score / 5, -1.0)
        return 0
    
    def _extract_keywords(self, feedbacks: List[FeedbackRecord]) -> List[str]:
        """提取关键词（简化版）"""
        # 这里可以集成真实的关键提取
        all_text = " ".join(f.content for f in feedbacks)
        
        # 简化：返回常见词
        common_keywords = []
        words = all_text.split()
        
        # 过滤长度 > 2 的词
        word_counts = {}
        for word in words:
            if len(word) > 2:
                word_counts[word] = word_counts.get(word, 0) + 1
        
        # 返回前 10 个
        sorted_words = sorted(word_counts.items(), key=lambda x: x[1], reverse=True)
        return [w[0] for w in sorted_words[:10]]
    
    def _analyze_trends(self, feedbacks: List[FeedbackRecord]) -> Dict[str, Any]:
        """分析趋势"""
        if not feedbacks:
            return {}
        
        # 按时间分组
        hourly_counts = {}
        for record in feedbacks:
            hour = record.timestamp[11:13]  # 提取小时
            hourly_counts[hour] = hourly_counts.get(hour, 0) + 1
        
        return {
            "hourly_distribution": hourly_counts,
            "peak_hour": max(hourly_counts.items(), key=lambda x: x[1])[0] if hourly_counts else None
        }
    
    def _log_feedback(self, record: FeedbackRecord) -> None:
        """记录反馈日志"""
        with open(self.feedback_log_path, "a") as f:
            f.write(json.dumps(asdict(record), default=str, ensure_ascii=False) + "\n")


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("☱ 兑反馈回传器 测试")
    print("=" * 60)
    
    transmitter = FeedbackTransmitter()
    
    # 测试 1：提交反馈
    print("\n📝 测试 1：提交反馈")
    
    record1 = transmitter.submit_feedback(
        content="系统运行得很好，响应速度很快！",
        feedback_type=FeedbackType.POSITIVE,
        source=FeedbackSource.USER,
        context={"session_id": "test_001"}
    )
    print(f"   反馈 ID: {record1.id}")
    print(f"   类型: {record1.type.value}")
    
    record2 = transmitter.submit_feedback(
        content="有时候响应有点慢，希望能优化",
        feedback_type=FeedbackType.NEGATIVE,
        source=FeedbackSource.USER,
        context={"session_id": "test_002"}
    )
    print(f"   反馈 ID: {record2.id}")
    print(f"   类型: {record2.type.value}")
    
    record3 = transmitter.submit_feedback(
        content="建议增加更多自定义选项",
        feedback_type=FeedbackType.SUGGESTION,
        source=FeedbackSource.USER
    )
    print(f"   反馈 ID: {record3.id}")
    print(f"   类型: {record3.type.value}")
    
    # 测试 2：处理反馈
    print("\n📝 测试 2：处理反馈")
    success = transmitter.process_feedback(record1.id, response="感谢反馈！")
    print(f"   处理结果: {'成功' if success else '失败'}")
    
    # 测试 3：分析反馈
    print("\n📝 测试 3：分析反馈")
    analysis = transmitter.analyze_feedback()
    print(f"   总反馈数: {analysis.total_count}")
    print(f"   情感分数: {analysis.sentiment_score}")
    print(f"   类型分布: {analysis.type_distribution}")
    
    # 测试 4：获取统计
    print("\n📝 测试 4：获取反馈统计")
    stats = transmitter.get_feedback_stats()
    print(f"   总反馈: {stats['total_feedback']}")
    print(f"   待处理: {stats['pending_feedback']}")
    print(f"   已处理: {stats['processed_feedback']}")
    
    print("\n✅ 兑反馈回传器测试完成")
