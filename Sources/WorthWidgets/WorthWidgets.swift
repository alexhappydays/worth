import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Shared widget helpers

enum WidgetStore {
    /// Fresh context per read so widget math always reflects the current
    /// App Group store contents.
    static func allSubscriptions() -> [Subscription] {
        let context = ModelContext(ModelContainerFactory.shared)
        let descriptor = FetchDescriptor<Subscription>(
            sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func subscription(uuid: UUID) -> Subscription? {
        let context = ModelContext(ModelContainerFactory.shared)
        let descriptor = FetchDescriptor<Subscription>(
            predicate: #Predicate { $0.uuid == uuid })
        return try? context.fetch(descriptor).first
    }

    /// Default pick: most-recently-logged, else first added.
    static func defaultSubscription() -> Subscription? {
        let subs = allSubscriptions()
        let logged = subs.compactMap { sub in
            sub.logs.map(\.timestamp).max().map { (sub, $0) }
        }
        if let mostRecent = logged.max(by: { $0.1 < $1.1 }) {
            return mostRecent.0
        }
        return subs.first
    }

    static var currencyCode: String {
        Locale.current.currency?.identifier ?? "GBP"
    }

    /// Refresh at the next day boundary so countdowns stay honest.
    static var nextDayBoundary: Date {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? .now
    }
}

/// Shared type scale + geometry so the widgets read as one dashboard.
enum WidgetStyle {
    static let numeralFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let bigNumeralFont = Font.system(size: 34, weight: .bold, design: .rounded)
    static let cornerRadius: CGFloat = 12
    static let ringWidth: CGFloat = 5
}

struct WidgetRing: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = WidgetStyle.ringWidth

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.03))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - App Intents

struct SubscriptionEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Subscription"
    static var defaultQuery = SubscriptionEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(sub: Subscription) {
        self.id = sub.uuid
        self.name = sub.name
    }
}

struct SubscriptionEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [SubscriptionEntity] {
        WidgetStore.allSubscriptions()
            .filter { identifiers.contains($0.uuid) }
            .map(SubscriptionEntity.init)
    }

    func suggestedEntities() async throws -> [SubscriptionEntity] {
        WidgetStore.allSubscriptions().map(SubscriptionEntity.init)
    }

    func defaultResult() async -> SubscriptionEntity? {
        WidgetStore.defaultSubscription().map(SubscriptionEntity.init)
    }
}

struct QuickLogConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Quick Log"
    static var description = IntentDescription("Choose which subscription to log.")

    @Parameter(title: "Subscription")
    var subscription: SubscriptionEntity?
}

/// Runs in the widget extension process — works with the app killed.
struct LogUseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Use"
    static var description = IntentDescription("Log one use of a subscription.")

    @Parameter(title: "Subscription")
    var subscription: SubscriptionEntity

    init() {}
    init(subscription: SubscriptionEntity) {
        self.subscription = subscription
    }

    func perform() async throws -> some IntentResult {
        let context = ModelContext(ModelContainerFactory.shared)
        let targetID = subscription.id
        let descriptor = FetchDescriptor<Subscription>(
            predicate: #Predicate { $0.uuid == targetID })
        if let sub = try context.fetch(descriptor).first {
            context.insert(UsageLog(timestamp: .now, subscription: sub))
            try context.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Quick-Log widget

struct QuickLogEntry: TimelineEntry {
    struct Sub {
        let entity: SubscriptionEntity
        let actionLabel: String
        let symbolName: String
        let costPerUseText: String?
        let priceLine: String
        let uses: Int
        let daysUntilDue: Int
        let tint: Color
        let progress: Double

        init(sub: Subscription) {
            let code = WidgetStore.currencyCode
            self.entity = SubscriptionEntity(sub: sub)
            self.actionLabel = sub.actionLabel
            self.symbolName = sub.symbolName
            self.costPerUseText = sub.costPerUse?.formatted(.currency(code: code))
            self.priceLine = "\(sub.price.formatted(.currency(code: code)))/\(sub.cycle.rawValue)"
            self.uses = sub.usesThisPeriod
            self.daysUntilDue = sub.daysUntilDue
            self.tint = sub.verdict.tint
            self.progress = sub.usageProgress
        }

        init(entity: SubscriptionEntity, actionLabel: String, symbolName: String,
             costPerUseText: String?, priceLine: String, uses: Int,
             daysUntilDue: Int, tint: Color, progress: Double) {
            self.entity = entity
            self.actionLabel = actionLabel
            self.symbolName = symbolName
            self.costPerUseText = costPerUseText
            self.priceLine = priceLine
            self.uses = uses
            self.daysUntilDue = daysUntilDue
            self.tint = tint
            self.progress = progress
        }
    }

    let date: Date
    let sub: Sub?
}

struct QuickLogProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickLogEntry {
        .sample
    }

    func snapshot(for configuration: QuickLogConfigurationIntent,
                  in context: Context) async -> QuickLogEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: QuickLogConfigurationIntent,
                  in context: Context) async -> Timeline<QuickLogEntry> {
        Timeline(entries: [entry(for: configuration)],
                 policy: .after(WidgetStore.nextDayBoundary))
    }

    private func entry(for configuration: QuickLogConfigurationIntent) -> QuickLogEntry {
        let sub: Subscription?
        if let chosen = configuration.subscription {
            sub = WidgetStore.subscription(uuid: chosen.id) ?? WidgetStore.defaultSubscription()
        } else {
            sub = WidgetStore.defaultSubscription()
        }
        return QuickLogEntry(date: .now, sub: sub.map(QuickLogEntry.Sub.init))
    }
}

struct QuickLogView: View {
    @Environment(\.widgetFamily) private var family
    var entry: QuickLogEntry

    var body: some View {
        Group {
            if let sub = entry.sub {
                switch family {
                case .systemMedium: mediumFace(sub)
                case .accessoryCircular: circularFace(sub)
                case .accessoryRectangular: rectangularFace(sub)
                default: smallFace(sub)
                }
            } else if family == .accessoryCircular {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "sterlingsign")
                }
            } else {
                NoSubscriptionsFace()
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private func smallFace(_ sub: QuickLogEntry.Sub) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                WidgetRing(progress: sub.progress, tint: sub.tint)
                    .frame(width: 18, height: 18)
                Text(sub.entity.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            if let cpu = sub.costPerUseText {
                Text(cpu)
                    .font(WidgetStyle.numeralFont)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("per use")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not used yet")
                    .font(.headline.weight(.semibold))
                Text(sub.priceLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
            logButton(sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mediumFace(_ sub: QuickLogEntry.Sub) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sub.entity.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let cpu = sub.costPerUseText {
                    Text(cpu)
                        .font(WidgetStyle.bigNumeralFont)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("per use · ^[\(sub.uses) use](inflect: true) this period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not used yet")
                        .font(.title2.weight(.bold))
                    Text(sub.priceLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(sub.daysUntilDue >= 0
                     ? "Renews in ^[\(sub.daysUntilDue) day](inflect: true)"
                     : "Renewal date passed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 10) {
                WidgetRing(progress: sub.progress, tint: sub.tint, lineWidth: 7)
                    .frame(width: 52, height: 52)
                logButton(sub)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Lock Screen circular: the whole face is the log button — ring + symbol.
    private func circularFace(_ sub: QuickLogEntry.Sub) -> some View {
        Button(intent: LogUseIntent(subscription: sub.entity)) {
            ZStack {
                AccessoryWidgetBackground()
                WidgetRing(progress: sub.progress, tint: sub.tint, lineWidth: 4)
                    .padding(3)
                Image(systemName: sub.symbolName)
                    .font(.body.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
    }

    private func rectangularFace(_ sub: QuickLogEntry.Sub) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(sub.entity.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(sub.costPerUseText.map { "\($0)/use" } ?? "Not used yet")
                    .font(.caption)
                Text("^[\(sub.uses) use](inflect: true) this period")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button(intent: LogUseIntent(subscription: sub.entity)) {
                Image(systemName: sub.symbolName)
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func logButton(_ sub: QuickLogEntry.Sub) -> some View {
        Button(intent: LogUseIntent(subscription: sub.entity)) {
            Label(sub.actionLabel, systemImage: sub.symbolName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
    }
}

struct NoSubscriptionsFace: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sterlingsign.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("No subscriptions yet")
                .font(.caption.weight(.semibold))
            Text("Open Worth to add one")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }
}

struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "QuickLog",
            intent: QuickLogConfigurationIntent.self,
            provider: QuickLogProvider()
        ) { entry in
            QuickLogView(entry: entry)
        }
        .configurationDisplayName("Quick Log")
        .description("Log a use with one tap — no app launch.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Bundle

@main
struct WorthWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickLogWidget()
        VerdictWidget()
        NextDueWidget()
    }
}

// MARK: - Previews

extension QuickLogEntry {
    static var sample: QuickLogEntry {
        QuickLogEntry(
            date: .now,
            sub: .init(
                entity: .init(id: UUID(), name: "Gym"),
                actionLabel: "Check In",
                symbolName: "dumbbell.fill",
                costPerUseText: Decimal(4.28).formatted(.currency(code: "GBP")),
                priceLine: "£29.99/monthly",
                uses: 7,
                daysUntilDue: 12,
                tint: .green,
                progress: 1.0))
    }

    static var empty: QuickLogEntry { QuickLogEntry(date: .now, sub: nil) }
}

#Preview("Quick Log small", as: .systemSmall) {
    QuickLogWidget()
} timeline: {
    QuickLogEntry.sample
    QuickLogEntry.empty
}

#Preview("Quick Log medium", as: .systemMedium) {
    QuickLogWidget()
} timeline: {
    QuickLogEntry.sample
    QuickLogEntry.empty
}

#Preview("Quick Log circular", as: .accessoryCircular) {
    QuickLogWidget()
} timeline: {
    QuickLogEntry.sample
    QuickLogEntry.empty
}

#Preview("Quick Log rectangular", as: .accessoryRectangular) {
    QuickLogWidget()
} timeline: {
    QuickLogEntry.sample
    QuickLogEntry.empty
}
