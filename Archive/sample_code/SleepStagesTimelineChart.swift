//
//  SleepStagesTimelineChart.swift
//  WellPath
//
//  Detailed sleep stages visualization using floating bars (RectangleMark)
//  Perfect for showing a single night's sleep progression
//

import SwiftUI
import Charts

// MARK: - Sleep Stages Timeline Chart

struct SleepStagesTimelineChart: View {
    let sleepPeriods: [SleepPeriod]
    let bedTime: Date
    let wakeTime: Date
    
    @State private var selectedPeriod: SleepPeriod?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerView
            
            // Timeline Chart
            timelineChart
                .frame(height: 200)
            
            // Stage Breakdown
            stageBreakdown
            
            // Details for selected period
            if let period = selectedPeriod {
                selectedPeriodDetail(period)
            }
        }
        .padding()
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sleep Stages Timeline")
                .font(.headline)
            Text("\(bedTime, format: .dateTime.hour().minute()) - \(wakeTime, format: .dateTime.hour().minute())")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Timeline Chart
    
    private var timelineChart: some View {
        Chart {
            ForEach(sleepPeriods) { period in
                RectangleMark(
                    xStart: .value("Start", period.startDate),
                    xEnd: .value("End", period.endDate),
                    y: .value("Stage", period.stage.rawValue),
                    height: .ratio(0.8)
                )
                .foregroundStyle(period.stage.color)
                .cornerRadius(4)
                .opacity(selectedPeriod?.id == period.id ? 1.0 : 0.8)
            }
            
            // Selection indicator
            if let selected = selectedPeriod {
                RectangleMark(
                    xStart: .value("Start", selected.startDate),
                    xEnd: .value("End", selected.endDate),
                    y: .value("Stage", selected.stage.rawValue),
                    height: .ratio(0.9)
                )
                .foregroundStyle(Color.clear)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(.white)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel()
            }
        }
        .chartYScale(
            domain: SleepStage.allCases.sorted(by: { $0.displayOrder < $1.displayOrder }).map(\.rawValue)
        )
        .chartXScale(domain: bedTime...wakeTime)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    selectedPeriod = findPeriod(at: date)
                                }
                            }
                    )
            }
        }
    }
    
    // MARK: - Stage Breakdown
    
    private var stageBreakdown: some View {
        HStack(spacing: 16) {
            ForEach(SleepStage.allCases, id: \.self) { stage in
                let duration = totalDuration(for: stage)
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stage.color)
                            .frame(width: 8, height: 8)
                        Text(stage.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(formatDuration(duration))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Selected Period Detail
    
    private func selectedPeriodDetail(_ period: SleepPeriod) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(period.stage.color)
                    .frame(width: 12, height: 12)
                Text(period.stage.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(period.startDate, format: .dateTime.hour().minute())
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatDuration(period.duration))
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(period.quality))%")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Helpers
    
    private func totalDuration(for stage: SleepStage) -> TimeInterval {
        sleepPeriods
            .filter { $0.stage == stage }
            .reduce(0) { $0 + $1.duration }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func findPeriod(at date: Date) -> SleepPeriod? {
        sleepPeriods.first { period in
            date >= period.startDate && date <= period.endDate
        }
    }
}

// MARK: - Hypnogram Style Chart (Alternative Visualization)

struct SleepHypnogramChart: View {
    let sleepPeriods: [SleepPeriod]
    let bedTime: Date
    let wakeTime: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hypnogram")
                .font(.headline)
            
            Chart {
                ForEach(sleepPeriods) { period in
                    LineMark(
                        x: .value("Time", period.startDate),
                        y: .value("Stage", period.stage.displayOrder)
                    )
                    .foregroundStyle(period.stage.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.stepEnd)
                    
                    LineMark(
                        x: .value("Time", period.endDate),
                        y: .value("Stage", period.stage.displayOrder)
                    )
                    .foregroundStyle(period.stage.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.stepEnd)
                    
                    // Fill area under line
                    AreaMark(
                        x: .value("Time", period.startDate),
                        y: .value("Stage", period.stage.displayOrder)
                    )
                    .foregroundStyle(period.stage.color.opacity(0.3))
                    .interpolationMethod(.stepEnd)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 1, 2, 3]) { value in
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(stageLabel(for: intValue))
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYScale(domain: -0.5...3.5)
            .chartXScale(domain: bedTime...wakeTime)
            .frame(height: 200)
        }
        .padding()
    }
    
    private func stageLabel(for order: Int) -> String {
        switch order {
        case 0: return "Awake"
        case 1: return "Light"
        case 2: return "REM"
        case 3: return "Deep"
        default: return ""
        }
    }
}

// MARK: - Preview

#Preview("Timeline") {
    SleepStagesTimelineChart(
        sleepPeriods: generateMockSleepPeriods(),
        bedTime: Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!,
        wakeTime: Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date())!
    )
}

#Preview("Hypnogram") {
    SleepHypnogramChart(
        sleepPeriods: generateMockSleepPeriods(),
        bedTime: Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!,
        wakeTime: Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date())!
    )
}

// MARK: - Mock Data

func generateMockSleepPeriods() -> [SleepPeriod] {
    let calendar = Calendar.current
    let bedTime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!
    
    let stages: [(SleepStage, Int)] = [
        (.light, 30),
        (.deep, 45),
        (.light, 20),
        (.rem, 60),
        (.light, 25),
        (.deep, 40),
        (.rem, 45),
        (.light, 30),
        (.awake, 10),
        (.rem, 55),
        (.light, 40)
    ]
    
    var periods: [SleepPeriod] = []
    var currentTime = bedTime
    
    for (stage, minutes) in stages {
        let endTime = calendar.date(byAdding: .minute, value: minutes, to: currentTime)!
        periods.append(SleepPeriod(
            startDate: currentTime,
            endDate: endTime,
            stage: stage,
            quality: Double.random(in: 70...95)
        ))
        currentTime = endTime
    }
    
    return periods
}
