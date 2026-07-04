import SwiftUI
import SwiftData
import WidgetKit

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
    .init(name: "Apple Music", priceGBP: 10.99, actionLabel: "Listened", symbol: "music.note.list"),
    .init(name: "Apple TV+", priceGBP: 8.99, actionLabel: "Watched", symbol: "tv.fill"),
    .init(name: "NOW TV", priceGBP: 9.99, actionLabel: "Watched", symbol: "tv.fill"),
    .init(name: "Paramount+", priceGBP: 7.99, actionLabel: "Watched", symbol: "play.fill"),
    .init(name: "Crunchyroll", priceGBP: 4.99, actionLabel: "Watched", symbol: "play.fill"),
    .init(name: "Deliveroo Plus", priceGBP: 3.49, actionLabel: "Ordered", symbol: "takeoutbag.and.cup.and.straw.fill"),
    .init(name: "Uber One", priceGBP: 5.99, actionLabel: "Used", symbol: "car.fill"),
    .init(name: "LinkedIn Premium", priceGBP: 29.99, actionLabel: "Used", symbol: "briefcase.fill"),
    .init(name: "Headspace", priceGBP: 9.99, actionLabel: "Meditated", symbol: "brain.head.profile"),
    .init(name: "Calm", priceGBP: 7.99, actionLabel: "Meditated", symbol: "moon.zzz.fill"),
    .init(name: "Strava", priceGBP: 8.99, actionLabel: "Tracked", symbol: "figure.run"),
    .init(name: "Peloton App", priceGBP: 12.99, actionLabel: "Worked Out", symbol: "figure.indoor.cycle"),
    .init(name: "The Times", priceGBP: 26.00, actionLabel: "Read", symbol: "newspaper.fill"),
    .init(name: "Google One", priceGBP: 1.59, actionLabel: "Used", symbol: "externaldrive.fill"),
    .init(name: "Dropbox", priceGBP: 9.99, actionLabel: "Used", symbol: "folder.fill"),
    .init(name: "Microsoft 365", priceGBP: 5.99, actionLabel: "Used", symbol: "doc.text.fill"),
    .init(name: "Adobe Creative Cloud", priceGBP: 56.98, actionLabel: "Created", symbol: "paintbrush.fill"),
    .init(name: "Notion", priceGBP: 7.50, actionLabel: "Used", symbol: "note.text"),
    .init(name: "Tinder Gold", priceGBP: 14.99, actionLabel: "Swiped", symbol: "flame.fill"),
    .init(name: "Coffee Club", priceGBP: 30.00, actionLabel: "Redeemed", symbol: "cup.and.saucer.fill"),
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
                        WidgetCenter.shared.reloadAllTimelines()
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
