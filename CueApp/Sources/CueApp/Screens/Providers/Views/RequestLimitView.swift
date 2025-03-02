import SwiftUI

/// A view for configuring request limits for a provider
struct RequestLimitView: View {
    let provider: Provider
    @Binding var requestLimit: Int
    @Binding var requestLimitWindow: Int
    
    // Predefined time window options in hours
    private let timeWindowOptions = [1, 3, 6, 12, 24, 48, 72]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Request Limits")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text("Set maximum number of requests allowed in a time period. Set to 0 for unlimited requests.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Request limit stepper
            HStack {
                Text("Max Requests:")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Stepper(value: $requestLimit, in: 0...1000, step: 10) {
                    HStack {
                        Text("\(requestLimit)")
                        Text(requestLimit == 0 ? "(Unlimited)" : "requests")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Only show time window picker if request limit is not unlimited
            if requestLimit > 0 {
                VStack(alignment: .leading) {
                    Text("Time Window:")
                        .foregroundColor(.primary)
                    
                    Picker("Time Window", selection: $requestLimitWindow) {
                        ForEach(timeWindowOptions, id: \.self) { hours in
                            Text(formatHours(hours))
                                .tag(hours)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            // Current usage information
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Usage")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Requests used:")
                    Spacer()
                    Text("\(UserDefaults.standard.requestCount(for: provider))/\(requestLimit == 0 ? "∞" : "\(requestLimit)")")
                }
                
                if let timestamp = UserDefaults.standard.requestLimitTimestamp(for: provider), requestLimit > 0 {
                    HStack {
                        Text("Resets in:")
                        Spacer()
                        Text(formatTimeRemaining(from: timestamp, windowHours: requestLimitWindow))
                    }
                }
                
                Button("Reset Counter") {
                    UserDefaults.standard.resetRequestCounters(for: provider)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 8)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
        .onChange(of: requestLimit) { _, newValue in
            UserDefaults.standard.setRequestLimit(newValue, for: provider)
            
            // If limit was previously 0 and now it's not, initialize the timestamp
            if UserDefaults.standard.requestLimitTimestamp(for: provider) == nil && newValue > 0 {
                UserDefaults.standard.setRequestLimitTimestamp(Date(), for: provider)
            }
        }
        .onChange(of: requestLimitWindow) { _, newValue in
            UserDefaults.standard.setRequestLimitWindow(newValue, for: provider)
        }
    }
    
    private func formatHours(_ hours: Int) -> String {
        switch hours {
        case 1:
            return "1 hour"
        case 24:
            return "1 day"
        case 48:
            return "2 days"
        case 72:
            return "3 days"
        default:
            return "\(hours) hours"
        }
    }
    
    private func formatTimeRemaining(from timestamp: Date, windowHours: Int) -> String {
        let windowSeconds = Double(windowHours * 3600)
        let elapsedTime = Date().timeIntervalSince(timestamp)
        let remainingTime = windowSeconds - elapsedTime
        
        if remainingTime <= 0 {
            return "Now"
        }
        
        let hours = Int(remainingTime) / 3600
        let minutes = (Int(remainingTime) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var limit = 50
        @State private var window = 24
        
        var body: some View {
            RequestLimitView(
                provider: .openai,
                requestLimit: $limit,
                requestLimitWindow: $window
            )
            .padding()
            .previewLayout(.sizeThatFits)
        }
    }
    
    return PreviewWrapper()
}