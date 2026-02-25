import SwiftUI
import Charts

struct CardActivityChartView: View {
    let cards: [WordCard]
    @Environment(\.dismiss) private var dismiss
    @State private var showAllDays = false

    private var dailyCounts: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: cards) { card in
            calendar.startOfDay(for: card.createdAt)
        }

        let endDate = calendar.startOfDay(for: Date())
        let daysToShow = showAllDays ? 90 : 30
        guard let startDate = calendar.date(byAdding: .day, value: -daysToShow + 1, to: endDate) else {
            return []
        }

        var results: [(date: Date, count: Int)] = []
        var current = startDate
        while current <= endDate {
            let count = grouped[current]?.count ?? 0
            results.append((date: current, count: count))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return results
    }

    private var totalInRange: Int {
        dailyCounts.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalInRange) cards")
                            .font(.title.bold())
                        Text("Last \(showAllDays ? 90 : 30) days")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Chart(dailyCounts, id: \.date) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Cards", item.count)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(2)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: showAllDays ? 14 : 7)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 220)
                    .padding(.horizontal)

                    Picker("Range", selection: $showAllDays) {
                        Text("30 Days").tag(false)
                        Text("90 Days").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Card Activity")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
