import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Next Due widget (small): the Smart Stack rotation hook

struct NextDueEntry: TimelineEntry {
    struct Sub {
        let name: String
        let symbolName: String
        let daysUntilDue: Int
        let priceLine: String
        let tint: Color
        let progress: Double
    }

    let date: Date
    let sub: Sub?
}

struct NextDueProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextDueEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (NextDueEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextDueEntry>) -> Void) {
        // Countdown changes at day boundaries; the pick can change at each
        // renewal. Refresh at whichever comes first.
        completion(Timeline(entries: [makeEntry()],
                            policy: .after(WidgetStore.nextDayBoundary)))
    }

    private func makeEntry() -> NextDueEntry {
        let code = WidgetStore.currencyCode
        let next = WidgetStore.allSubscriptions()
            .min { $0.nextDueDate < $1.nextDueDate }
        let sub = next.map { sub in
            NextDueEntry.Sub(
                name: sub.name,
                symbolName: sub.symbolName,
                daysUntilDue: sub.daysUntilDue,
                priceLine: "\(sub.price.formatted(.currency(code: code)))/\(sub.cycle.rawValue)",
                tint: sub.verdict.tint,
                progress: sub.usageProgress)
        }
        return NextDueEntry(date: .now, sub: sub)
    }
}

struct NextDueWidgetView: View {
    var entry: NextDueEntry

    var body: some View {
        Group {
            if let sub = entry.sub {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        WidgetRing(progress: sub.progress, tint: sub.tint)
                            .frame(width: 18, height: 18)
                        Text(sub.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    Text(countdownText(days: sub.daysUntilDue))
                        .font(WidgetStyle.numeralFont)
                        .foregroundStyle(sub.tint)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(sub.daysUntilDue >= 0 ? "until renewal" : "renewal passed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    Text(sub.priceLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                NoSubscriptionsFace()
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private func countdownText(days: Int) -> String {
        switch days {
        case ..<0: "Overdue"
        case 0: "Today"
        case 1: "1 day"
        default: "\(days) days"
        }
    }
}

struct NextDueWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextDue", provider: NextDueProvider()) { entry in
            NextDueWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Due")
        .description("Which subscription bills next, and when.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Previews

extension NextDueEntry {
    static var sample: NextDueEntry {
        NextDueEntry(
            date: .now,
            sub: .init(name: "Netflix", symbolName: "play.fill",
                       daysUntilDue: 3,
                       priceLine: "£12.99/monthly",
                       tint: .yellow, progress: 0.4))
    }

    static var empty: NextDueEntry { NextDueEntry(date: .now, sub: nil) }
}

#Preview("Next Due small", as: .systemSmall) {
    NextDueWidget()
} timeline: {
    NextDueEntry.sample
    NextDueEntry.empty
}
