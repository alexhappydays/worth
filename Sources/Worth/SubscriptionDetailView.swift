import SwiftUI
import SwiftData

extension Verdict {
    var tint: Color {
        switch self {
        case .great: .green
        case .okay: .yellow
        case .waste: .red
        case .noData: .gray
        }
    }

    var caption: String {
        switch self {
        case .great: "Great value"
        case .okay: "Getting there"
        case .waste: "Barely used"
        case .noData: "No uses logged yet"
        }
    }
}

extension Subscription {
    /// Ring fill fraction: 7+ uses this period fills the ring (matches the
    /// verdict threshold for .great in Models.swift).
    var usageProgress: Double {
        min(1.0, Double(usesThisPeriod) / 7.0)
    }

    var daysUntilDue: Int {
        Calendar.current.dateComponents(
            [.day], from: .now, to: nextDueDate).day ?? 0
    }
}

struct SubscriptionDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var sub: Subscription

    @State private var showingEdit = false
    @State private var ringProgress: Double = 0
    @State private var logTrigger = 0

    private var currencyCode: String { Locale.current.currency?.identifier ?? "GBP" }
    private var sortedLogs: [UsageLog] { sub.logs.sorted { $0.timestamp > $1.timestamp } }

    var body: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    verdictGauge
                    nextDueLine
                    logButton
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("History") {
                if sortedLogs.isEmpty {
                    ContentUnavailableView(
                        "Nothing logged yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Tap \u{201C}\(sub.actionLabel)\u{201D} every time you use \(sub.name)."))
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(sortedLogs) { log in
                        HStack {
                            Image(systemName: sub.symbolName)
                                .foregroundStyle(.tint)
                            Text(log.timestamp, format: .dateTime.weekday(.wide).day().month().hour().minute())
                            Spacer()
                            Text(log.timestamp, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { idx in
                        idx.map { sortedLogs[$0] }.forEach(context.delete)
                        withAnimation(.easeOut(duration: 0.6)) {
                            ringProgress = sub.usageProgress
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(sub.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { showingEdit = true }
        }
        .sheet(isPresented: $showingEdit) {
            EditSubscriptionView(sub: sub)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: logTrigger)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
                ringProgress = sub.usageProgress
            }
        }
    }

    private var verdictGauge: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 18)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(sub.verdict.tint,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                if let cpu = sub.costPerUse {
                    Text(cpu, format: .currency(code: currencyCode))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("per use")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(sub.price, format: .currency(code: currencyCode))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("per \(sub.cycle.rawValue), unused")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(sub.verdict.caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(sub.verdict.tint)
            }
            .padding(28)
        }
        .frame(width: 230, height: 230)
        .padding(.top, 8)
    }

    private var nextDueLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
            if sub.daysUntilDue >= 0 {
                Text("Renews in ^[\(sub.daysUntilDue) day](inflect: true) · \(sub.price.formatted(.currency(code: currencyCode)))/\(sub.cycle.rawValue)")
            } else {
                Text("Renewal date passed · \(sub.price.formatted(.currency(code: currencyCode)))/\(sub.cycle.rawValue)")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var logButton: some View {
        Button {
            withAnimation(.snappy) {
                context.insert(UsageLog(subscription: sub))
                logTrigger += 1
            }
            withAnimation(.easeOut(duration: 0.6)) {
                ringProgress = sub.usageProgress
            }
        } label: {
            Label(sub.actionLabel, systemImage: sub.symbolName)
                .font(.headline)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(Capsule())
        .symbolEffect(.bounce, value: logTrigger)
    }
}

// MARK: - Edit sheet

struct EditSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var sub: Subscription

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $sub.name)
                    TextField("Price", value: $sub.price,
                              format: .currency(code: Locale.current.currency?.identifier ?? "GBP"))
                        .keyboardType(.decimalPad)
                    Picker("Billing", selection: $sub.cycle) {
                        ForEach(BillingCycle.allCases) { Text($0.label).tag($0) }
                    }
                    DatePicker("Next payment", selection: $sub.nextDueDate,
                               displayedComponents: .date)
                }
                Section("Log button") {
                    TextField("Label", text: $sub.actionLabel)
                    TextField("SF Symbol name", text: $sub.symbolName)
                }
            }
            .navigationTitle("Edit \(sub.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(sub.name.isEmpty || sub.price <= 0)
                }
            }
        }
    }
}
