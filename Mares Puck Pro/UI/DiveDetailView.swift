import SwiftUI
import Charts

/// Detailed view of an individual dive
struct DiveDetailView: View {
    let dive: DiveData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header info
                    headerSection
                    
                    // Dive statistics
                    statisticsSection
                    
                    // Dive profile chart
                    if !dive.profileSamples.isEmpty {
                        profileChartSection
                    }
                    
                    // Decompression stops
                    if dive.hasDecompressionStops {
                        decompressionSection
                    }
                    
                    // Equipment info
                    equipmentSection
                }
                .padding()
            }
            .navigationTitle("Dive #\(dive.diveNumber)")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "water.waves")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(dive.date, style: .date)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(dive.date, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dive Statistics")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Duration",
                    value: dive.formattedDuration,
                    icon: "clock",
                    color: .blue
                )
                
                StatCard(
                    title: "Max Depth",
                    value: dive.formattedMaxDepth,
                    icon: "arrow.down",
                    color: .red
                )
                
                StatCard(
                    title: "Avg Depth",
                    value: dive.formattedAverageDepth,
                    icon: "minus",
                    color: .orange
                )
                
                if let tempRange = dive.formattedTemperatureRange {
                    StatCard(
                        title: "Temperature",
                        value: tempRange,
                        icon: "thermometer",
                        color: .cyan
                    )
                }
                
                StatCard(
                    title: "Water Type",
                    value: dive.waterType.rawValue,
                    icon: dive.waterType == .saltwater ? "drop.fill" : "drop",
                    color: dive.waterType == .saltwater ? .blue : .cyan
                )
                
                StatCard(
                    title: "Gas Type",
                    value: dive.gasType.rawValue,
                    icon: "lungs",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Profile Chart Section
    
    private var profileChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dive Profile")
                .font(.headline)
            
            Chart(dive.profileSamples, id: \.time) { sample in
                LineMark(
                    x: .value("Time", sample.time / 60), // Convert to minutes
                    y: .value("Depth", -sample.depth)   // Negative for underwater
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                if let temperature = sample.temperature {
                    LineMark(
                        x: .value("Time", sample.time / 60),
                        y: .value("Temperature", temperature)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXAxisLabel("Time (minutes)")
            .chartYAxisLabel("Depth (meters)")
            .frame(height: 200)
            .padding()
            .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Decompression Section
    
    private var decompressionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Decompression Stops")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(dive.decompressionStops.indices, id: \.self) { index in
                    let stop = dive.decompressionStops[index]
                    
                    HStack {
                        Image(systemName: "pause.circle")
                            .foregroundColor(.orange)
                        
                        Text("\(stop.depth, specifier: "%.0f")m")
                            .fontWeight(.medium)
                        
                        Text("for")
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(stop.duration / 60)) min")
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
    
    // MARK: - Equipment Section
    
    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Equipment")
                .font(.headline)
            
            HStack {
                Label(dive.gasType.rawValue, systemImage: "lungs")
                
                if let oxygen = dive.oxygenPercentage {
                    Text("(\(oxygen, specifier: "%.0f")% O₂)")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
            if let surfaceInterval = dive.surfaceInterval {
                HStack {
                    Label("Surface Interval", systemImage: "clock")
                    
                    Spacer()
                    
                    Text("\(Int(surfaceInterval / 3600))h \(Int((surfaceInterval.truncatingRemainder(dividingBy: 3600)) / 60))m")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}