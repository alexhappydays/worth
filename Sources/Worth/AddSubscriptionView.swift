import SwiftUI
import SwiftData

struct SubscriptionPreset: Identifiable {
    let id = UUID()
    let name: String
    let priceGBP: Decimal
    let actionLabel: String
    let symbol: String
}

/// Static local list — no network, keeps the "data never leaves your phone" promise.
/// Prices are editable defaults, not fetched.
let popularPresets: [SubscriptionPreset] = [
    .init(name: "Netflix", priceGBP: 12.99, actionLabel: "Watched", symbol: "play.fill"),
    .init(name: "Spotify", priceGBP: 11.99, actionLabel: "Listened", symbol: "music.note"),
    .init(name: "Gym", priceGBP: 29.99, actionLabel: "Check In", symbol: "dumbbell.fill"),
    .init(name: "Disney+", priceGBP: 8.99, actionLabel: "Watched", symbol: "play.fill"),
    .init(name: "Amazon Prime", priceGBP: 8.99, actionLabel: "Used", symbol: "shippingbox.fill"),
    .init(name: "YouTube Premium", priceGBP: 12.99, actionLabel: "Watched", symbol: "play.rectangle.fill"),
    .init(name: "iCloud+", priceGBP: 2.99, actionLabel: "Used", symbol: "icloud.fill"),
    .init(name: "Audible", priceGBP: 7.99, actionLabel: "Listened", symbol: "headphones"),
    .init(name: "PlayStation Plus", priceGBP: 10.99, actionLabel: "Played", symbol: "gamecontroller.fill"),
    .init(name: "Xbox Game Pass", priceGBP: 12.99, actionLabel: "Played", symbol: "gamecontroller.fill"),
    .init(name: "Duolingo", priceGBP: 12.99, actionLabel: "Practiced", symbol: "graduationcap.fill"),
    .init(name: "ChatGPT Plus", priceGBP: 20.00, actionLabel: "Used", symbol: "sparkles"),
]

struct AddSubscriptionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var price: Decimal = 0
    @State private var cycle: BillingCycle = .monthly
    @State private var actionLabel = "Used"
    @State private var symbol = "checkmark.circle.fill"
    @State private var nextDue = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        NavigationStack {
            Form {
                Section("Popular") {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(popularPresets) { p in
                            Button {
                                name = p.name; price = p.priceGBP
                                actionLabel = p.actionLabel; symbol = p.symbol
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: p.symbol)
                                    Text(p.name).font(.caption2).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Price", value: $price,
                              format: .currency(code: Locale.current.currency?.identifier ?? "GBP"))
                        .keyboardType(.decimalPad)
                    Picker("Billing", selection: $cycle) {
                        ForEach(BillingCycle.allCases) { Text($0.label).tag($0) }
                    }
                    DatePicker("Next payment", selection: $nextDue, displayedComponents: .date)
                    TextField("Log button label", text: $actionLabel)
                }
            }
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        context.insert(Subscription(
                            name: name, price: price, cycle: cycle,
                            actionLabel: actionLabel, symbolName: symbol,
                            nextDueDate: nextDue))
                        dismiss()
                    }
                    .disabled(name.isEmpty || price <= 0)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
