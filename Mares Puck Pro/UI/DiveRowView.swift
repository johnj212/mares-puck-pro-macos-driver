import SwiftUI

/// Individual dive row in the dive list
struct DiveRowView: View {
    let dive: DiveData
    
    var body: some View {
        HStack {
            // Dive number badge
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text("\(dive.diveNumber)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Date and duration
                HStack {
                    Text(dive.date, style: .date)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(dive.formattedDuration)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Depth info
                HStack {
                    Label(dive.formattedMaxDepth, systemImage: "arrow.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Label("Avg \(dive.formattedAverageDepth)", systemImage: "minus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Water type indicator
                    HStack(spacing: 4) {
                        Image(systemName: dive.waterType == .saltwater ? "drop.fill" : "drop")
                            .foregroundColor(dive.waterType == .saltwater ? .blue : .teal)
                        Text(dive.waterType.rawValue)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                // Temperature and decompression status
                HStack {
                    if let tempRange = dive.formattedTemperatureRange {
                        Label(tempRange, systemImage: "thermometer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if dive.hasDecompressionStops {
                        Label("Deco", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}