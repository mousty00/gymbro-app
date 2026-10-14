import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbro_app/core/mock/mock_backend.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gymbro_app/features/share/share_cards.dart';
import 'package:gymbro_app/features/share/share_links.dart';
import 'package:gymbro_app/models/notification.dart';
import 'package:gymbro_app/models/user.dart';
import 'package:gymbro_app/models/workout.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  group('link condivisi', () {
    test('scheda e profilo puntano al sito', () {
      expect(ShareLinks.workout('abc'), 'https://repbirds.com/w/abc');
      expect(ShareLinks.profile('giulia.fit'), 'https://repbirds.com/u/giulia.fit');
    });

    test('la notifica di una scheda ricevuta apre la scheda', () {
      final n = AppNotification.fromJson({
        'id': 'n1',
        'type': 'WORKOUT_SHARED',
        'actor': {'id': 'u2', 'username': 'giulia.fit'},
        'referenceId': 'w4',
        'detail': 'Full body',
      });
      expect(n.kind, NotificationKind.workoutShared);
      expect(n.route, '/workout/w4');
      expect(n.text, contains('Full body'));
    });
  });

  group('invio di una scheda (mock)', () {
    late Dio dio;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://mock/api'))
        ..interceptors.add(MockBackend(latency: Duration.zero, enabled: () => true));
    });

    Future<int?> share(String id, Map<String, dynamic> body) async {
      final res = await dio.post<dynamic>('/workouts/$id/share', data: body);
      return (res.data as Map)['recipients'] as int?;
    }

    Matcher status(int code) => throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', code));

    test('ad amici e gruppi, non a sconosciuti', () async {
      expect(
        await share('w2', {
          'usernames': ['giulia.fit', 'mousty'],
        }),
        1,
      );
      expect(
        await share('w2', {
          'groupIds': ['g2'],
        }),
        greaterThanOrEqualTo(1),
      );
      await expectLater(
        share('w2', {
          'usernames': ['luca.cali'],
        }),
        status(403),
      );
      await expectLater(share('w2', {'usernames': <String>[]}), status(400));
    });
  });

  group('card da condividere', () {
    final workout = Workout(
      id: 'w1',
      name: 'Una scheda dal nome davvero molto lungo per vedere se va a capo bene',
      user: const SimpleUser(id: 'u1', username: 'mousty'),
      exercises: [
        for (var i = 1; i <= 8; i++)
          WorkoutExercise(
            id: 'we$i',
            workoutId: 'w1',
            exerciseId: 'e$i',
            exerciseName: 'Esercizio numero $i con nome lungo',
            sets: 4,
            reps: 8,
            weight: 62.5,
            restSeconds: 90,
            position: i,
          ),
      ],
    );

    Future<void> pump(WidgetTester tester, Widget card) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: card)),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byWidget(card)), shareCardSize);
    }

    testWidgets('scheda: mostra i primi esercizi e quanti altri', (tester) async {
      await pump(tester, WorkoutShareCard(workout: workout));
      expect(find.text('+ altri 3'), findsOneWidget);
      expect(find.text('repbirds.com/w/w1'), findsOneWidget);
    });

    testWidgets('sessione completata', (tester) async {
      final session = WorkoutHistory(
        id: 'h1',
        workoutId: 'w1',
        groupId: 'g1',
        startedAt: DateTime(2026, 10, 14, 18),
        completedAt: DateTime(2026, 10, 14, 19, 5),
        notes: 'Nuovo record sulla panca, e anche un po\' di fatica in più del solito sulle trazioni',
      );
      await pump(tester, SessionShareCard(session: session, workout: workout, username: 'mousty'));
      expect(find.text('1 h 5 min'), findsOneWidget);
    });

    testWidgets('profilo', (tester) async {
      const user = User(id: 'u1', username: 'mousty', firstName: 'Mousty');
      await pump(tester, const ProfileShareCard(user: user, sessions: 42, trained: Duration(hours: 31), friends: 7));
      expect(find.text('@mousty'), findsOneWidget);
      expect(find.text('repbirds.com/u/mousty'), findsOneWidget);
    });
  });
}
