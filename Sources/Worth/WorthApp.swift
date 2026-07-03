import SwiftUI
import SwiftData

@main
struct WorthApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [Subscription.self, UsageLog.self])
        // Phase 4 will move this to an App Group container shared with widgets.
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Subscription.nextDueDate) private var subs: [Subscription]
    @State private var showingAdd = false

    private var annualWaste: Decimal {
        subs.filter { $0.verdict == .waste }.reduce(0) { $0 + $1.annualCost }
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
                    SubscriptionRow(sub: sub)
                }
                .onDelete { idx in idx.map { subs[$0] }.forEach(context.delete) }
            }
            .listStyle(.plain)
            .navigationTitle("Worth")
            .toolbar {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
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

    var body: some View {
        HStack(spacing: 14) {
            VerdictRing(verdict: sub.verdict)
            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name).font(.headline)
                Text(costLine).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                context.insert(UsageLog(subscription: sub))
            } label: {
                Label(sub.actionLabel, systemImage: sub.symbolName)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.tint.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
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
    var color: Color {
        switch verdict {
        case .great: .green
        case .okay: .yellow
        case .waste: .red
        case .noData: .gray
        }
    }
    var body: some View {
        Circle()
            .stroke(color, lineWidth: 5)
            .frame(width: 34, height: 34)
            .overlay(Circle().fill(color.opacity(0.15)))
    }
}
