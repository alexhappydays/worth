import SwiftUI
import SwiftData
import WidgetKit

@main
struct WorthApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // App Group container shared with the widget extension (Phase 4).
        .modelContainer(ModelContainerFactory.shared)
    }
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(\.modelContext) private var context
    @Query private var metas: [AppMeta]

    var body: some View {
        Group {
            if hasOnboarded {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .task {
            // Record first launch exactly once; ProGate.founderCutoff compares
            // against this to decide the founder cohort (Phase 6).
            if metas.isEmpty {
                context.insert(AppMeta())
            }
        }
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Subscription.nextDueDate) private var subs: [Subscription]
    @Query private var metas: [AppMeta]
    @State private var showingAdd = false

    private var annualWaste: Decimal {
        subs.filter { $0.verdict == .waste }.reduce(0) { $0 + $1.annualCost }
    }

    // PRO-GATED: Phase 6 caps free-tier subscription count; unlocked for now.
    private var canAddSubscription: Bool {
        ProGate.hasPro(metas.first) || subs.count < ProGate.freeSubscriptionLimit
    }

    var body: some View {
        NavigationStack {
            List {
                if annualWaste > 0 {
                    WasteHeadline(amount: annualWaste)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                ForEach(subs) { sub in
                    NavigationLink {
                        SubscriptionDetailView(sub: sub)
                    } label: {
                        SubscriptionRow(sub: sub)
                    }
                }
                .onDelete { idx in
                    idx.map { subs[$0] }.forEach(context.delete)
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            .listStyle(.plain)
            .navigationTitle("Worth")
            .toolbar {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .disabled(!canAddSubscription)
            }
            .sheet(isPresented: $showingAdd) { AddSubscriptionView() }
            .overlay {
                if subs.isEmpty {
                    ContentUnavailableView(
                        "No subscriptions yet",
                        systemImage: "creditcard",
                        description: Text("Add one and start logging every use."))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct WasteHeadline: View {
    let amount: Decimal
    var body: some View {
        VStack(spacing: 4) {
            Text("You're wasting")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(amount, format: .currency(code: Locale.current.currency?.identifier ?? "GBP"))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.red)
            Text("per year on barely-used subscriptions")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct SubscriptionRow: View {
    @Environment(\.modelContext) private var context
    let sub: Subscription
    @State private var logTrigger = 0

    var body: some View {
        HStack(spacing: 14) {
            VerdictRing(verdict: sub.verdict)
            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name).font(.headline)
                Text(costLine)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 12)
            Button {
                withAnimation(.snappy) {
                    context.insert(UsageLog(subscription: sub))
                    logTrigger += 1
                }
                WidgetCenter.shared.reloadAllTimelines()
            } label: {
                Label(sub.actionLabel, systemImage: sub.symbolName)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.tint.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.borderless)
            .symbolEffect(.bounce, value: logTrigger)
            .sensoryFeedback(.impact(weight: .medium), trigger: logTrigger)
        }
        .padding(.vertical, 6)
    }

    private var costLine: String {
        let code = Locale.current.currency?.identifier ?? "GBP"
        if let cpu = sub.costPerUse {
            return "\(cpu.formatted(.currency(code: code)))/use · \(sub.usesThisPeriod) uses"
        }
        return "Not used this period — \(sub.price.formatted(.currency(code: code)))/\(sub.cycle.rawValue)"
    }
}

struct VerdictRing: View {
    let verdict: Verdict
    var body: some View {
        Circle()
            .stroke(verdict.tint, lineWidth: 5)
            .frame(width: 34, height: 34)
            .overlay(Circle().fill(verdict.tint.opacity(0.15)))
    }
}
