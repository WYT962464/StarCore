//
//  HexagramTypes.swift
//  StarCore - 六十四卦类型定义
//
//  完整的卦象类型系统，包括两仪、四象、八卦、六十四卦
//

import Foundation

// MARK: - 爻（Yao）- 卦的基本单位

/// 爻 - 卦象的基本组成单位
enum Yao: Int {
    case yin = 0   // 阴爻 --
    case yang = 1  // 阳爻 —
    
    var symbol: String {
        switch self {
        case .yin: return "--"
        case .yang: return "—"
        }
    }
    
    var description: String {
        switch self {
        case .yin: return "阴"
        case .yang: return "阳"
        }
    }
    
    /// 取反
    var opposite: Yao {
        switch self {
        case .yin: return .yang
        case .yang: return .yin
        }
    }
}

// MARK: - 两仪（Two Yi）

/// 两仪 - 阴阳
enum TwoYi: Int, CaseIterable, Hashable {
    case yin = 0    // 阴
    case yang = 1   // 阳
    
    var yao: Yao {
        Yao(rawValue: rawValue)!
    }
    
    var description: String {
        switch self {
        case .yin: return "阴"
        case .yang: return "阳"
        }
    }
    
    /// 两仪生四象
    func generatesFourXiang() -> [FourXiang] {
        // 两仪自身 + 与其他两仪组合
        return FourXiang.allCases
    }
}

// MARK: - 四象（Four Xiang）

/// 四象 - 少阳、太阳、少阴、太阴
enum FourXiang: Int, CaseIterable, Hashable {
    case shaoYang = 0   // 少阳 ☰ (下阴上阳)
    case taiYang = 1    // 太阳 ☱ (下阳上阳)
    case shaoYin = 2    // 少阴 ☲ (下阳上阴)
    case taiYin = 3     // 太阴 ☷ (下阴上阴)
    
    /// 两爻表示（下爻，上爻）
    var yaoPair: (lower: Yao, upper: Yao) {
        switch self {
        case .shaoYang: return (.yin, .yang)
        case .taiYang: return (.yang, .yang)
        case .shaoYin: return (.yang, .yin)
        case .taiYin: return (.yin, .yin)
        }
    }
    
    var description: String {
        switch self {
        case .shaoYang: return "少阳"
        case .taiYang: return "太阳"
        case .shaoYin: return "少阴"
        case .taiYin: return "太阴"
        }
    }
    
    /// 四象对应季节
    var season: Season {
        switch self {
        case .shaoYang: return .spring    // 少阳主春
        case .taiYang: return .summer     // 太阳主夏
        case .shaoYin: return .autumn     // 少阴主秋
        case .taiYin: return .winter      // 太阴主冬
        }
    }
    
    /// 四象对应 StarCore 意识阶段
    var consciousnessPhase: ConsciousnessPhase {
        switch self {
        case .shaoYang, .taiYang: return .execution
        case .shaoYin: return .introspection
        case .taiYin: return .subconscious
        }
    }
}

/// 季节
enum Season: String {
    case spring = "春"
    case summer = "夏"
    case autumn = "秋"
    case winter = "冬"
}

// MARK: - 八卦（Eight Trigrams）

/// 八卦 - 乾、兑、离、震、巽、坎、艮、坤
enum EightTrigrams: Int, CaseIterable, Hashable {
    case qian = 0   // 乾 ☰ 天
    case dui = 1    // 兑 ☱ 泽
    case li = 2     // 离 ☲ 火
    case zhen = 3   // 震 ☳ 雷
    case xun = 4    // 巽 ☴ 风
    case kan = 5    // 坎 ☵ 水
    case gen = 6    // 艮 ☶ 山
    case kun = 7    // 坤 ☷ 地
    
    /// 三爻表示（初爻、二爻、三爻）
    var yaoTriple: (first: Yao, second: Yao, third: Yao) {
        switch self {
        case .qian: return (.yang, .yang, .yang)   // 乾三连
        case .dui: return (.yang, .yang, .yin)     // 兑上缺
        case .li: return (.yang, .yin, .yang)      // 离中虚
        case .zhen: return (.yin, .yin, .yang)     // 震仰盂
        case .xun: return (.yang, .yin, .yin)      // 巽下断
        case .kan: return (.yin, .yang, .yin)      // 坎中满
        case .gen: return (.yin, .yang, .yang)     // 艮覆碗
        case .kun: return (.yin, .yin, .yin)       // 坤六断
        }
    }
    
    /// 四象组合（下四象，上四象）
    var fourXiangPair: (lower: FourXiang, upper: FourXiang) {
        // 八卦 = 两个四象的组合
        // 下卦（初爻 + 二爻）→ 下四象
        // 上卦（二爻 + 三爻）→ 上四象
        let yao = yaoTriple
        
        let lowerXiang: FourXiang
        switch (yao.first, yao.second) {
        case (.yin, .yin): lowerXiang = .taiYin
        case (.yin, .yang): lowerXiang = .shaoYang
        case (.yang, .yin): lowerXiang = .shaoYin
        case (.yang, .yang): lowerXiang = .taiYang
        }
        
        let upperXiang: FourXiang
        switch (yao.second, yao.third) {
        case (.yin, .yin): upperXiang = .taiYin
        case (.yin, .yang): upperXiang = .shaoYang
        case (.yang, .yin): upperXiang = .shaoYin
        case (.yang, .yang): upperXiang = .taiYang
        }
        
        return (lowerXiang, upperXiang)
    }
    
    var description: String {
        switch self {
        case .qian: return "乾"
        case .dui: return "兑"
        case .li: return "离"
        case .zhen: return "震"
        case .xun: return "巽"
        case .kan: return "坎"
        case .gen: return "艮"
        case .kun: return "坤"
        }
    }
    
    /// 自然象征
    var naturalSymbol: NaturalSymbol {
        switch self {
        case .qian: return .sky
        case .dui: return .lake
        case .li: return .fire
        case .zhen: return .thunder
        case .xun: return .wind
        case .kan: return .water
        case .gen: return .mountain
        case .kun: return .earth
        }
    }
    
    /// 家庭象征
    var familySymbol: FamilyMember? {
        switch self {
        case .qian: return .father
        case .kun: return .mother
        case .zhen: return .eldestSon
        case .xun: return .eldestDaughter
        case .kan: return .middleSon
        case .li: return .middleDaughter
        case .gen: return .youngestSon
        case .dui: return .youngestDaughter
        }
    }
    
    /// 八卦属性
    var attributes: TrigramAttributes {
        switch self {
        case .qian: return .init(element: .sky, quality: .creative, direction: .northwest, season: .lateAutumn)
        case .dui: return .init(element: .lake, quality: .joyful, direction: .west, season: .autumn)
        case .li: return .init(element: .fire, quality: .clarity, direction: .south, season: .summer)
        case .zhen: return .init(element: .thunder, quality: .arousing, direction: .east, season: .spring)
        case .xun: return .init(element: .wind, quality: .gentle, direction: .southeast, season: .lateSpring)
        case .kan: return .init(element: .water, quality: .abysmal, direction: .north, season: .winter)
        case .gen: return .init(element: .mountain, quality: .still, direction: .northeast, season: .lateWinter)
        case .kun: return .init(element: .earth, quality: .receptive, direction: .southwest, season: .lateSummer)
        }
    }
    
    /// 错卦（对立卦）
    var oppositeTrigram: EightTrigrams {
        switch self {
        case .qian: return .kun
        case .kun: return .qian
        case .dui: return .gen
        case .gen: return .dui
        case .li: return .kan
        case .kan: return .li
        case .zhen: return .xun
        case .xun: return .zhen
        }
    }
    
    /// 综卦（反向）- 八卦自身反向等于自身（对称）
    var inverseTrigram: EightTrigrams {
        // 八卦反向后可能变成另一个卦
        let yao = yaoTriple
        let reversed = (yao.third, yao.second, yao.first)
        
        switch reversed {
        case (.yang, .yang, .yang): return .qian
        case (.yin, .yang, .yang): return .dui
        case (.yang, .yin, .yang): return .li
        case (.yang, .yin, .yin): return .zhen
        case (.yin, .yin, .yang): return .xun
        case (.yin, .yang, .yin): return .kan
        case (.yang, .yang, .yin): return .gen
        case (.yin, .yin, .yin): return .kun
        default: return self
        }
    }
}

/// 自然象征
enum NaturalSymbol {
    case sky, lake, fire, thunder, wind, water, mountain, earth
}

/// 家庭象征
enum FamilyMember {
    case father, mother
    case eldestSon, eldestDaughter
    case middleSon, middleDaughter
    case youngestSon, youngestDaughter
}

/// 八卦属性
struct TrigramAttributes {
    let element: NaturalSymbol
    let quality: TrigramQuality
    let direction: CompassDirection
    let season: Season
}

enum TrigramQuality {
    case creative, joyful, clarity, arousing, gentle, abysmal, still, receptive
}

enum CompassDirection: String {
    case north = "北"
    case northeast = "东北"
    case east = "东"
    case southeast = "东南"
    case south = "南"
    case southwest = "西南"
    case west = "西"
    case northwest = "西北"
}

// MARK: - 六十四卦（Sixty-Four Hexagrams）

/// 六十四卦
struct Hexagram: Hashable, CustomStringConvertible {
    let lowerTrigram: EightTrigrams  // 下卦（内卦）
    let upperTrigram: EightTrigrams  // 上卦（外卦）
    
    var description: String {
        "\(upperTrigram.description)\(lowerTrigram.description)"
    }
    
    /// 卦名（传统名称）
    var name: String {
        HexagramNames.name(for: self)
    }
    
    /// 六爻表示（从下到上：初爻到上爻）
    var yaoLine: [Yao] {
        let lower = lowerTrigram.yaoTriple
        let upper = upperTrigram.yaoTriple
        return [
            lower.first,   // 初爻
            lower.second,  // 二爻
            lower.third,   // 三爻
            upper.first,   // 四爻
            upper.second,  // 五爻
            upper.third    // 上爻
        ]
    }
    
    /// 二进制表示（0-63）
    var binaryIndex: Int {
        yaoLine.enumerated().reduce(0) { result, element in
            result + (element.element.rawValue << element.offset)
        }
    }
    
    /// 所有 64 卦
    static let allHexagrams: [Hexagram] = {
        var hexagrams: [Hexagram] = []
        for lower in EightTrigrams.allCases {
            for upper in EightTrigrams.allCases {
                hexagrams.append(Hexagram(lowerTrigram: lower, upperTrigram: upper))
            }
        }
        return hexagrams
    }()
    
    /// 常用卦象快捷访问
    static let qian = Hexagram(lowerTrigram: .qian, upperTrigram: .qian)  // 乾为天
    static let kun = Hexagram(lowerTrigram: .kun, upperTrigram: .kun)     // 坤为地
    static let tai = Hexagram(lowerTrigram: .qian, upperTrigram: .kun)    // 地天泰
    static let pi = Hexagram(lowerTrigram: .kun, upperTrigram: .qian)     // 天地否
    static let jian = Hexagram(lowerTrigram: .kan, upperTrigram: .gen)    // 水山蹇
    static let jie = Hexagram(lowerTrigram: .gen, upperTrigram: .kan)     // 山水解
    static let qian2 = Hexagram(lowerTrigram: .zhen, upperTrigram: .kan)  // 水雷屯
    static let meng = Hexagram(lowerTrigram: .kan, upperTrigram: .gen)    // 山水蒙
}

/// 卦名映射
enum HexagramNames {
    static func name(for hexagram: Hexagram) -> String {
        // 简化版：使用上下卦名称组合
        // 完整版应包含 64 卦的传统名称
        return "\(hexagram.upperTrigram.description)\(hexagram.lowerTrigram.description)"
    }
}

// MARK: - 意识流阶段

/// 意识流阶段（对应四象）
enum ConsciousnessPhase: String, CaseIterable {
    case execution = "执行"      // 两仪/四象 - 实时响应
    case introspection = "内省"  // 四象 - 反思调整
    case subconscious = "潜意识" // 八卦 - 长期模式
}

// MARK: - 潜意识模式（对应八卦）

/// 潜意识模式
enum SubconsciousPattern: String, CaseIterable {
    case activeExecution = "主动执行"      // 乾、震
    case socialInteraction = "社交互动"    // 兑、离
    case adaptiveLearning = "适应学习"     // 巽、坎
    case restorativeRecovery = "恢复休息"  // 艮、坤
}

extension EightTrigrams {
    var subconsciousPattern: SubconsciousPattern {
        switch self {
        case .qian, .zhen: return .activeExecution
        case .dui, .li: return .socialInteraction
        case .xun, .kan: return .adaptiveLearning
        case .gen, .kun: return .restorativeRecovery
        }
    }
}

// MARK: - 循环层级

/// 循环层级
enum CycleLevel: Int, CaseIterable {
    case twoYi = 0        // 两仪微循环（100ms）
    case fourXiang = 1    // 四象小循环（分钟级）
    case eightTrigrams = 2  // 八卦中循环（小时级）
    case sixtyFour = 3    // 六十四卦大循环（天级）
}

extension CycleLevel {
    var interval: TimeInterval {
        switch self {
        case .twoYi: return 0.1        // 100ms
        case .fourXiang: return 60     // 1 分钟
        case .eightTrigrams: return 3600  // 1 小时
        case .sixtyFour: return 86400  // 24 小时
        }
    }
    
    var description: String {
        switch self {
        case .twoYi: return "两仪微循环"
        case .fourXiang: return "四象小循环"
        case .eightTrigrams: return "八卦中循环"
        case .sixtyFour: return "六十四卦大循环"
        }
    }
}
