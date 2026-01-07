//
//  SignalNoiseWidgetLiveActivity.swift
//  SignalNoiseWidget
//
//  Created by Luke Brevoort on 12/22/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// IMPORTANT: This struct MUST be named exactly "LiveActivitiesAppAttributes"
// and the ContentState MUST match the one in the live_activities plugin
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState
    
    // This MUST include appGroupId to match the live_activities plugin's definition
    public struct ContentState: Codable, Hashable {
        var appGroupId: String
    }
    
    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

// Shared UserDefaults for accessing Flutter data
let sharedDefault = UserDefaults(suiteName: "group.com.signalnoise.app")!

@available(iOS 16.1, *)
struct SignalNoiseWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    TaskTypeIndicator(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerView(context: context, size: .expanded)
                }
                DynamicIslandExpandedRegion(.center) {
                    TaskTitleView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressBarView(context: context)
                }
            } compactLeading: {
                // Compact leading (pill left side)
                CompactLeadingView(context: context)
            } compactTrailing: {
                // Compact trailing (pill right side)
                TimerView(context: context, size: .compact)
            } minimal: {
                // Minimal view (when other activities present)
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View
struct LockScreenView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let taskTitle = sharedDefault.string(forKey: context.attributes.prefixedKey("taskTitle")) ?? "Task"
        let taskType = sharedDefault.string(forKey: context.attributes.prefixedKey("taskType")) ?? "signal"
        let startedAt = sharedDefault.integer(forKey: context.attributes.prefixedKey("startedAt"))
        let timeSpentBefore = sharedDefault.integer(forKey: context.attributes.prefixedKey("timeSpentBefore"))
        
        let isSignal = taskType == "signal"
        let startDate = Date(timeIntervalSince1970: Double(startedAt) / 1000.0)
        
        HStack(spacing: 16) {
            // Task type indicator
            VStack {
                Image(systemName: isSignal ? "flag.fill" : "circle.dotted")
                    .font(.title2)
                    .foregroundColor(isSignal ? .primary : .secondary)
                Text(isSignal ? "Signal" : "Noise")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50)
            
            // Task title and timer
            VStack(alignment: .leading, spacing: 4) {
                Text(taskTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "timer")
                        .font(.caption)
                    Text(startDate, style: .timer)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    
                    if timeSpentBefore > 0 {
                        Text("+ \(formatTime(seconds: timeSpentBefore))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Goal indicator
            VStack {
                Text("80%")
                    .font(.caption)
                    .fontWeight(.bold)
                Text("Goal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Dynamic Island Components
struct TaskTypeIndicator: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let taskType = sharedDefault.string(forKey: context.attributes.prefixedKey("taskType")) ?? "signal"
        let isSignal = taskType == "signal"
        
        VStack {
            Image(systemName: isSignal ? "flag.fill" : "circle.dotted")
                .font(.title2)
            Text(isSignal ? "Signal" : "Noise")
                .font(.caption2)
        }
    }
}

struct TaskTitleView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let taskTitle = sharedDefault.string(forKey: context.attributes.prefixedKey("taskTitle")) ?? "Task"
        
        Text(taskTitle)
            .font(.headline)
            .lineLimit(1)
    }
}

enum TimerSize {
    case compact
    case expanded
}

struct TimerView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    let size: TimerSize
    
    var body: some View {
        let startedAt = sharedDefault.integer(forKey: context.attributes.prefixedKey("startedAt"))
        let startDate = Date(timeIntervalSince1970: Double(startedAt) / 1000.0)
        
        Text(startDate, style: .timer)
            .font(size == .compact ? .caption : .system(.body, design: .monospaced))
            .fontWeight(.medium)
            .monospacedDigit()
    }
}

struct ProgressBarView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let taskType = sharedDefault.string(forKey: context.attributes.prefixedKey("taskType")) ?? "signal"
        let isSignal = taskType == "signal"
        
        HStack {
            Text("Focus on what matters")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if isSignal {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

struct CompactLeadingView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let taskType = sharedDefault.string(forKey: context.attributes.prefixedKey("taskType")) ?? "signal"
        let isSignal = taskType == "signal"
        
        Image(systemName: isSignal ? "flag.fill" : "circle.dotted")
            .foregroundColor(isSignal ? .primary : .secondary)
    }
}

struct MinimalView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let taskType = sharedDefault.string(forKey: context.attributes.prefixedKey("taskType")) ?? "signal"
        let isSignal = taskType == "signal"
        
        Image(systemName: isSignal ? "flag.fill" : "timer")
    }
}

// MARK: - Preview
#Preview("Lock Screen", as: .content, using: LiveActivitiesAppAttributes()) {
    SignalNoiseWidgetLiveActivity()
} contentStates: {
    LiveActivitiesAppAttributes.ContentState(appGroupId: "group.com.signalnoise.app")
}
