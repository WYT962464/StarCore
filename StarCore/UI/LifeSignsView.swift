/**
 * LifeSignsView.swift
 * 生命体征详细视图
 */

import SwiftUI

struct LifeSignsView: View {
    @EnvironmentObject var hardwareSensor: HardwareSensor
    
    var body: some View {
        List {
            Section(header: Text("生理数据")) {
                HStack {
                    Text("CPU 使用率")
                    Spacer()
                    Text("\(Int(hardwareSensor.cpuUsage))%")
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("电池电量")
                    Spacer()
                    Text("\(Int(hardwareSensor.batteryLevel))%")
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("热状态")
                    Spacer()
                    Text(hardwareSensor.thermalState == 0 ? "正常" : "警告")
                        .foregroundColor(hardwareSensor.thermalState == 0 ? .green : .orange)
                }
                
                HStack {
                    Text("内存使用")
                    Spacer()
                    Text("\(hardwareSensor.memoryUsage) MB")
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("磁盘使用")
                    Spacer()
                    Text("\(hardwareSensor.diskUsage) GB")
                        .foregroundColor(.blue)
                }
            }
            
            Section(header: Text("映射关系")) {
                HStack {
                    Text("心率")
                    Spacer()
                    Text("CPU → 60-120 bpm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("能量")
                    Spacer()
                    Text("电池 → 0-1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("体温")
                    Spacer()
                    Text("热状态 → 36.5-39°C")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("生命体征")
    }
}
