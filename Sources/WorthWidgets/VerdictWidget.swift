import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Verdict widget (large): dashboard of the top subscriptions by cost

struct VerdictEntry: TimelineEntry {
    struct Row: Identifiable {
        let id: UUID
        let name: String
        let symbolName: String
        let costPerUseText: String?
        let annualText: String
        let tint: Color
        let progress: Double
    }

    let date: Date
    /// Formatted annual waste, nil when nothing is being wasted.
    let wasteText: String?
    let rows: [Row]
}

struct VerdictProvider: TimelineProvider {
    func placeholder(in context: Context) -> VerdictEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (VerdictEntry) -> Void) {
        completion(makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerdictEntry>) -> Void) {
        // Entries at now plus the next few renewal dates: when a billing
        // period rolls over, the per-period math changes, and .atEnd makes
        // WidgetKit ask for a fresh timeline right after.
        let renewals = WidgetStore.allSubscriptions()
            .map(\.nextDueDate)
            .filter { $0 > .now }
            .sorted()
            .prefix(4)
        let dates = [Date.now] + renewals.map { $0.addingTimeInterval(60) }
        completion(Timeline(entries: dates.map(makeEntry(at:)), policy: .atEnd))
    }

    private func makeEntry(at date: Date) -> VerdictEntry {
        let code = WidgetStore.currencyCode
        let subs = WidgetStore.allSubscriptions()

        let waste = subs.filter { $0.verdict == .waste }
            .reduce(Decimal(0)) { $0 + $1.annualCost }
        let rows = subs
            .sorted { $0.annualCost > $1.annualCost }
            .prefix(4)
            .map { sub in
                VerdictEntry.Row(
                    id: sub.uuid,
                    name: sub.name,
                    symbolName: sub.symbolName,
                    costPerUseText: sub.costPerUse?.formatted(.currency(code: code)),
                    annualText: "\(sub.annualCost.formatted(.currency(code: code)))/yr",
                    tint: sub.verdict.tint,
                    progress: sub.usageProgress)
            }
        return VerdictEntry(
            date: date,
            wasteText: waste > 0 ? waste.formatted(.currency(code: code)) : nil,
            rows: Array(rows))
    }
}

struct VerdictWidgetView: View {
    var entry: VerdictEntry

    var body: some View {
        Group {
            if entry.rows.isEmpty {
                NoSubscriptionsFace()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    Spacer(minLength: 0)
                    VStack(spacing: 10) {
                        ForEach(entry.rows) { row in
                            rowView(row)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let waste = entry.wasteText {
                Text("Wasting \(Text(waste).foregroundStyle(.red))/yr")
                    .font(WidgetStyle.numeralFont)
                Text("on barely-used subscriptions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("No waste 🎉")
                    .font(WidgetStyle.numeralFont)
                Text("every subscription is earning its keep")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func rowView(_ row: VerdictEntry.Row) -> some View {
        HStack(spacing: 10) {
            WidgetRing(progress: row.progress, tint: row.tint, lineWidth: 4)
                .frame(width: 20, height: 20)
            Image(systemName: row.symbolName)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(row.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text(row.costPerUseText.map { "\($0)/use" } ?? "Not used yet")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(row.costPerUseText == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(row.tint))
                Text(row.annualText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct VerdictWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Verdict", provider: VerdictProvider()) { entry in
            VerdictWidgetView(entry: entry)
        }
        .configurationDisplayName("Verdict Dashboard")
        .description("Your biggest subscriptions and what each use really costs.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Previews

extension VerdictEntry {
    static var sample: VerdictEntry {
        VerdictEntry(
            date: .now,
            wasteText: Decimal(311.88).formatted(.currency(code: "GBP")),
            rows: [
                Row(id: UUID(), name: "Adobe Creative Cloud", symbolName: "paintbrush.fill",
                    costPerUseText: "£28.49", annualText: "£683.76/yr", tint: .red, progress: 0.28),
                Row(id: UUID(), name: "Gym", symbolName: "dumbbell.fill",
                    costPerUseText: "£3.75", annualText: "£359.88/yr", tint: .green, progress: 1.0),
                Row(id: UUID(), name: "The Times", symbolName: "newspaper.fill",
                    costPerUseText: nil, annualText: "£312.00/yr", tint: .gray, progress: 0),
                Row(id: UUID(), name: "Spotify", symbolName: "music.note",
                    costPerUseText: "£0.60", annualText: "£143.88/yr", tint: .green, progress: 1.0),
            ])
    }

    static var empty: VerdictEntry {
        VerdictEntry(date: .now, wasteText: nil, rows: [])
    }
}

#Preview("Verdict large", as: .systemLarge) {
    VerdictWidget()
} timeline: {
    VerdictEntry.sample
    VerdictEntry.empty
}
