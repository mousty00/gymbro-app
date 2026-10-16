import '../../models/workout.dart';

/// Dove sei nella sessione: un esercizio e una serie alla volta, nell'ordine
/// della scheda. Dalla lista si può saltare a un altro esercizio.
class SessionProgress {
  SessionProgress(this.exercises);

  final List<WorkoutExercise> exercises;
  final Map<String, int> _done = {};
  int _focus = 0;

  /// Per salvare e riprendere la sessione.
  Map<String, int> get done => Map.unmodifiable(_done);
  int get focusIndex => _focus;

  void restore(Map<String, int> done, int focus) {
    _done
      ..clear()
      ..addAll(done);
    _focus = exercises.isEmpty ? 0 : focus.clamp(0, exercises.length - 1);
  }

  int doneOf(WorkoutExercise e) => _done[e.id] ?? 0;
  bool isComplete(WorkoutExercise e) => doneOf(e) >= e.sets;

  int get totalSets => exercises.fold(0, (a, e) => a + e.sets);
  int get doneSets => exercises.fold(0, (a, e) => a + doneOf(e).clamp(0, e.sets));
  bool get allDone => exercises.every(isComplete);

  /// Primo esercizio non finito, partendo da quello scelto.
  int? get currentIndex => _firstIncompleteFrom(_focus);
  WorkoutExercise? get current => currentIndex == null ? null : exercises[currentIndex!];

  /// Numero della serie da fare (1-based).
  int get currentSet => current == null ? 0 : doneOf(current!) + 1;
  bool get isLastSet => current != null && currentSet == current!.sets;

  /// L'esercizio che arriva dopo quello corrente, se ne manca ancora uno.
  WorkoutExercise? get next {
    final i = currentIndex;
    if (i == null) return null;
    final n = _firstIncompleteFrom(i + 1, skip: i);
    return n == null ? null : exercises[n];
  }

  /// Segna fatta la serie corrente; restituisce l'esercizio (per il recupero).
  WorkoutExercise? completeSet() {
    final i = currentIndex;
    if (i == null) return null;
    final e = exercises[i];
    _done[e.id] = doneOf(e) + 1;
    _focus = i;
    return e;
  }

  /// Toglie l'ultima serie segnata di [e] e ci torna sopra.
  void undo(WorkoutExercise e) {
    if (doneOf(e) == 0) return;
    _done[e.id] = doneOf(e) - 1;
    _focus = exercises.indexOf(e);
  }

  void focus(WorkoutExercise e) => _focus = exercises.indexOf(e);

  int? _firstIncompleteFrom(int start, {int? skip}) {
    for (var k = 0; k < exercises.length; k++) {
      final i = (start + k) % exercises.length;
      if (i != skip && !isComplete(exercises[i])) return i;
    }
    return null;
  }
}
