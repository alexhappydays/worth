import WidgetKit
import SwiftUI

// Phase 1 placeholder: proves the extension target builds.
// Phase 4 replaces this with Quick-Log (interactive AppIntent),
// Verdict gauge, and Next Due — reading a shared App Group SwiftData store.

struct PlaceholderEntry: TimelineEntry { let date: Date }

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { .init(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(.init(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now)], policy: .never))
    }
}

struct WorthWidgetView: View {
    var entry: PlaceholderEntry
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sterlingsign.circle.fill").font(.title)
            Text("Worth").font(.headline)
        }
        .containerBackground(.background, for: .widget)
    }
}

struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickLog", provider: PlaceholderProvider()) {
            WorthWidgetView(entry: $0)
        }
        .configurationDisplayName("Quick Log")
        .description("Log a use without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct WorthWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickLogWidget()
    }
}
