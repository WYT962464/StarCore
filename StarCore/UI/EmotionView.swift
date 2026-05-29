/**
 * EmotionView.swift
 * 情绪引擎详细视图
 */

import SwiftUI

struct EmotionView: View {
    @EnvironmentObject var hardwareSensor: HardwareSensor
    
    var body: some View {
        List {
            Section(header: Text("情绪维度")) {
                HStack {
                    Text("唤醒度 (Arousal)")
                    Spacer()
                    Text("\(Int(hardwareSensor.arousal * 100))")
                        .foregroundColor(.purple)
                }
                
                HStack {
                    Text("效价 (Valence)")
                    Spacer()
                    Text("\(Int(hardwareSensor.valence * 100))")
                        .foregroundColor(.purple)
                }
            }
            
            Section(header: Text("主导情绪")) {
                HStack {
                    Text("当前状态")
                    Spacer()
                    Text(hardwareSensor.currentEmotion)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
            }
            
            Section(header: Text("情绪计算")) {
                Text("基于生理数据实时计算：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("CPU负载 → 唤醒度")
                    Spacer()
                }
                
                HStack {
                    Text("电池趋势 → 效价")
                    Spacer()
                }
                
                HStack {
                    Text("历史交互 → 情绪记忆")
                    Spacer()
                }
            }
        }
        .navigationTitle("情绪引擎")
    }
}
