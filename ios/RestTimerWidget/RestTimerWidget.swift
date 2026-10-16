import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RestTimerWidgetBundle: WidgetBundle {
  var body: some Widget {
    RestTimerLiveActivity()
  }
}

/// Giallo del recupero nell'app (AppColors.amber) e inchiostro scuro sopra.
private let amber = Color(red: 0xF2 / 255, green: 0xB3 / 255, blue: 0x3D / 255)
private let ink = Color(red: 0x11 / 255, green: 0x13 / 255, blue: 0x22 / 255)

struct RestTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RestActivityAttributes.self) { context in
      // Schermata di blocco: il timer si aggiorna da solo, senza svegliare l'app.
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(context.attributes.title).font(.headline)
          Text(context.attributes.subtitle).font(.caption).opacity(0.7)
        }
        Spacer()
        countdown(context.state.endsAt)
          .font(.system(size: 44, weight: .heavy).monospacedDigit())
          .multilineTextAlignment(.trailing)
      }
      .foregroundColor(ink)
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
      .activityBackgroundTint(amber)
      .activitySystemActionForegroundColor(ink)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(context.attributes.title, systemImage: "hourglass").foregroundColor(amber)
        }
        DynamicIslandExpandedRegion(.trailing) {
          countdown(context.state.endsAt)
            .font(.title.weight(.heavy).monospacedDigit())
            .foregroundColor(amber)
            .multilineTextAlignment(.trailing)
        }
      } compactLeading: {
        Image(systemName: "hourglass").foregroundColor(amber)
      } compactTrailing: {
        countdown(context.state.endsAt)
          .monospacedDigit()
          .foregroundColor(amber)
          .frame(maxWidth: 52)
      } minimal: {
        Image(systemName: "hourglass").foregroundColor(amber)
      }
    }
  }

  private func countdown(_ end: Date) -> Text {
    // a fine recupero resta su 0:00 finché l'app non chiude l'attività
    Text(timerInterval: Date()...max(end, Date()), countsDown: true)
  }
}
