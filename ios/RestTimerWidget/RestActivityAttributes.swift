import ActivityKit
import Foundation

/// Live Activity del recupero tra le serie: conto alla rovescia nella schermata di blocco e
/// nella Dynamic Island. Compilato sia nell'app (che la avvia) sia nell'estensione (che la disegna).
struct RestActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var endsAt: Date
  }

  /// Testi già tradotti dall'app.
  var title: String
  var subtitle: String
}
