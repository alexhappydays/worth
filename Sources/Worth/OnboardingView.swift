import SwiftUI
import SwiftData
import WidgetKit

/// First-launch-only flow. Goal: first subscription added in under 30 seconds.
struct OnboardingView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var page = 0

    var body: some View {
        ZStack {
            if page == 0 {
                WelcomePage { withAnimation(.snappy) { page = 1 } }
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                PresetPickerPage { hasOnboarded = true }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Screen 1: value prop

private struct WelcomePage: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "sterlingsign.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .padding(.bottom, 24)
            Text("Is your subscription\nactually worth it?")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text("Log every use. See the real cost-per-use.\nCancel the waste.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Spacer()
            Label("Your data never leaves your phone", systemImage: "lock.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
        }
        .padding(24)
    }
}

// MARK: - Screen 2: preset multi-select grid

private struct PresetPickerPage: View {
    @Environment(\.modelContext) private var context
    let onFinish: () -> Void

    @State private var selected: Set<UUID> = []
    @State private var editedPrices: [UUID: Decimal] = [:]
    @State private var editingPreset: SubscriptionPreset?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]
    private var currencyCode: String { Locale.current.currency?.identifier ?? "GBP" }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("What do you pay for?")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("Tap to select. Hold to edit the price.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(popularPresets) { preset in
                        PresetTile(
                            preset: preset,
                            price: editedPrices[preset.id] ?? preset.priceGBP,
                            isSelected: selected.contains(preset.id),
                            currencyCode: currencyCode
                        ) {
                            if selected.contains(preset.id) {
                                selected.remove(preset.id)
                            } else {
                                selected.insert(preset.id)
                            }
                        } onLongPress: {
                            editingPreset = preset
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            VStack(spacing: 10) {
                Button {
                    addSelected()
                    onFinish()
                } label: {
                    Text(selected.isEmpty
                         ? "Select a few to start"
                         : "Add \(selected.count) subscription\(selected.count == 1 ? "" : "s")")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Capsule())
                .disabled(selected.isEmpty)

                Button("Skip for now") { onFinish() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .sensoryFeedback(.selection, trigger: selected)
        .sheet(item: $editingPreset) { preset in
            PresetPriceSheet(
                preset: preset,
                price: editedPrices[preset.id] ?? preset.priceGBP,
                currencyCode: currencyCode
            ) { newPrice in
                editedPrices[preset.id] = newPrice
                selected.insert(preset.id)
            }
            .presentationDetents([.height(220)])
        }
    }

    private func addSelected() {
        let nextDue = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
        for preset in popularPresets where selected.contains(preset.id) {
            context.insert(Subscription(
                name: preset.name,
                price: editedPrices[preset.id] ?? preset.priceGBP,
                cycle: .monthly,
                actionLabel: preset.actionLabel,
                symbolName: preset.symbol,
                nextDueDate: nextDue))
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct PresetTile: View {
    let preset: SubscriptionPreset
    let price: Decimal
    let isSelected: Bool
    let currencyCode: String
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: preset.symbol)
                .font(.title3)
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            Text(preset.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Text(price, format: .currency(code: currencyCode))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            isSelected ? AnyShapeStyle(.tint.opacity(0.2)) : AnyShapeStyle(.quaternary),
            in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 1.5))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onTap)
        .onLongPressGesture(perform: onLongPress)
    }
}

private struct PresetPriceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preset: SubscriptionPreset
    @State var price: Decimal
    let currencyCode: String
    let onSave: (Decimal) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Price per month", value: $price,
                          format: .currency(code: currencyCode))
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))
            }
            .navigationTitle(preset.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(price)
                        dismiss()
                    }
                    .disabled(price <= 0)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
