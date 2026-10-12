import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/env.dart';

/// Backend finto in memoria, attivo quando `Env.useMock` è vero
/// (`flutter run -t lib/main_mock.dart` o `--dart-define=USE_MOCK=true`).
///
/// È un interceptor di dio: risponde alle stesse rotte di gymbro-api con le
/// stesse forme JSON, così repository, modelli e schermate restano identici.
/// I dati vivono in memoria: le modifiche (post, like, schede, gruppi…)
/// valgono finché l'app resta aperta.
///
/// Comportamenti utili per provare la UX:
/// - qualunque username e password fanno il login come `mousty`;
/// - lo username `nonverificato` simula l'email non verificata (403);
/// - la password `sbagliata` simula credenziali errate (401);
/// - il codice OTP `000000` è sempre rifiutato, gli altri sono accettati.
class MockBackend extends Interceptor {
  MockBackend({this.latency = const Duration(milliseconds: 350), bool Function()? enabled})
      : enabled = enabled ?? (() => Env.useMock) {
    _seed();
  }

  final Duration latency;

  /// Se falso le richieste passano al server vero.
  final bool Function() enabled;

  /// Immagini caricate dall'app in modalità mock, lette da `AppImage`.
  static final Map<String, Uint8List> uploads = {};

  static const uploadScheme = 'mock-upload:';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!enabled()) return handler.next(options);
    await Future<void>.delayed(latency);
    try {
      final data = await _route(options);
      handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: data));
    } on _MockError catch (e) {
      _reject(options, handler, e.status, e.message);
    } catch (e) {
      // Un bug del mock non deve lasciare la richiesta appesa.
      _reject(options, handler, 500, 'Mock: $e');
    }
  }

  void _reject(RequestOptions options, RequestInterceptorHandler handler, int status, String message) {
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: {'status': status, 'message': message, 'timestamp': _iso(DateTime.now())},
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- dati

  final _now = DateTime.now();
  var _seq = 100;
  String _id(String prefix) => '$prefix${_seq++}';

  late Map<String, dynamic> _me;
  final _users = <Map<String, dynamic>>[];
  final _exercises = <Map<String, dynamic>>[];
  final _workouts = <Map<String, dynamic>>[];
  final _history = <Map<String, dynamic>>[];
  final _groups = <Map<String, dynamic>>[];
  final _posts = <Map<String, dynamic>>[];
  final _friendships = <Map<String, dynamic>>[];

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  Map<String, dynamic> _user(String id, String username, String first, String last, int ageDays) => {
        'id': id,
        'username': username,
        'email': '$username@gymbro.it',
        'firstName': first,
        'lastName': last,
        'birthDate': '1998-05-12',
        'image': null,
        'roleName': 'USER',
        'isAccountVerified': true,
        'createdAt': _iso(_now.subtract(Duration(days: ageDays))),
      };

  Map<String, dynamic> _simple(Map<String, dynamic> u) =>
      {'id': u['id'], 'username': u['username'], 'image': u['image'], 'isAccountVerified': u['isAccountVerified']};

  Map<String, dynamic> _userBy(String username) =>
      _users.firstWhere((u) => u['username'] == username, orElse: () => throw _MockError(404, 'Utente non trovato'));

  void _seed() {
    _me = _user('u1', 'mousty', 'Moustapha', 'D.', 140);
    final giulia = _user('u2', 'giulia.fit', 'Giulia', 'Rossi', 300);
    final marco = _user('u3', 'marco_lifts', 'Marco', 'Bianchi', 200);
    final sara = _user('u4', 'sara.runs', 'Sara', 'Verdi', 90);
    final luca = _user('u5', 'luca.cali', 'Luca', 'Neri', 40);
    _users.addAll([_me, giulia, marco, sara, luca]);

    const ex = [
      ('Panca piana', 'Petto'), ('Squat', 'Gambe'), ('Stacco da terra', 'Schiena'), ('Military press', 'Spalle'),
      ('Trazioni', 'Schiena'), ('Curl manubri', 'Bicipiti'), ('French press', 'Tricipiti'), ('Hip thrust', 'Glutei'),
      ('Affondi', 'Gambe'), ('Plank', 'Addome'), ('Crunch', 'Addome'), ('Corsa', 'Cardio'), ('Burpees', 'Full body'),
    ];
    for (var i = 0; i < ex.length; i++) {
      _exercises.add({
        'id': 'e$i',
        'name': ex[i].$1,
        'muscleGroup': ex[i].$2,
        'description': null,
        'isPublic': true,
        'createdBy': i < 3 ? _me : giulia,
      });
    }

    Map<String, dynamic> we(String wid, int pos, int exIdx, int sets, int reps, num? kg, int rest) => {
          'id': '$wid-$pos',
          'workoutId': wid,
          'exerciseId': 'e$exIdx',
          'exerciseName': ex[exIdx].$1,
          'sets': sets,
          'reps': reps,
          'weight': kg,
          'restSeconds': rest,
          'position': pos,
        };

    final today = _now.weekday;
    _workouts.addAll([
      _workout('w1', _me, 'Push day', 'Petto, spalle e tricipiti. Carichi progressivi.', true, [today, (today + 2) % 7 + 1], '18:30',
          [we('w1', 1, 0, 4, 8, 70, 120), we('w1', 2, 3, 4, 10, 40, 90), we('w1', 3, 6, 3, 12, 25, 60), we('w1', 4, 9, 3, 1, null, 45)]),
      _workout('w2', _me, 'Leg day', 'Forza e volume per le gambe.', false, [3, 6], '10:00',
          [we('w2', 1, 1, 5, 5, 100, 150), we('w2', 2, 8, 3, 10, 20, 90), we('w2', 3, 7, 4, 12, 80, 90)]),
      _workout('w3', _me, 'Pull & core', null, false, [5], null,
          [we('w3', 1, 4, 4, 8, null, 120), we('w3', 2, 2, 3, 5, 120, 180), we('w3', 3, 5, 3, 12, 14, 60)]),
      _workout('w4', giulia, 'Full body 45\'', 'Circuito veloce per chi ha poco tempo.', true, [2], null,
          [we('w4', 1, 1, 3, 12, 40, 60), we('w4', 2, 12, 3, 15, null, 45), we('w4', 3, 9, 3, 1, null, 45)]),
      _workout('w5', marco, 'Powerlifting base', '5x5 sui fondamentali.', true, [1, 3, 5], '07:00',
          [we('w5', 1, 1, 5, 5, 140, 180), we('w5', 2, 0, 5, 5, 100, 180), we('w5', 3, 2, 1, 5, 180, 240)]),
    ]);

    void hist(int daysAgo, int minutes, String wid, {String? group, String? notes}) {
      final start = _now.subtract(Duration(days: daysAgo, hours: 2));
      _history.add({
        'id': _id('h'),
        'userId': _me['id'],
        'workoutId': wid,
        'groupId': group,
        'startedAt': _iso(start),
        'completedAt': _iso(start.add(Duration(minutes: minutes))),
        'notes': notes,
      });
    }

    hist(0, 52, 'w1', notes: 'Panca 72,5 kg x 8, nuovo record!');
    hist(2, 61, 'w2');
    hist(4, 38, 'w3');
    hist(6, 70, 'w2', group: 'g1', notes: 'Con Giulia e Marco');
    hist(9, 48, 'w1');
    hist(12, 55, 'w2');
    hist(15, 44, 'w3');

    Map<String, dynamic> member(String gid, Map<String, dynamic> u, String status) => {
          'id': _id('m'),
          'workoutGroupId': gid,
          'user': _simple(u),
          'status': status,
          'createdAt': _iso(_now.subtract(const Duration(days: 1))),
        };

    _groups.addAll([
      _group('g1', 'Leg day del sabato', 'w2', _me, _now.add(const Duration(days: 5, hours: 3)),
          [member('g1', giulia, 'accepted'), member('g1', marco, 'accepted'), member('g1', sara, 'invited')]),
      _group('g2', 'Push con Marco', 'w5', marco, _now.add(const Duration(days: 2, hours: 6)), [member('g2', _me, 'accepted')]),
      _group('g3', 'Corsa al parco', 'w4', sara, _now.add(const Duration(days: 8)), [member('g3', _me, 'invited')]),
    ]);

    Map<String, dynamic> post(Map<String, dynamic> u, String text, int? img, int hoursAgo, List<String> likes,
        List<(String, String)> comments) {
      final id = _id('p');
      final at = _iso(_now.subtract(Duration(hours: hoursAgo)));
      return {
        'id': id,
        'user': u,
        'content': text,
        'image': img == null ? null : 'asset:assets/mock/post$img.jpg',
        'createdAt': at,
        'updatedAt': at,
        'comments': <Map<String, dynamic>>[
          for (final c in comments)
            {'id': _id('c'), 'postId': id, 'username': c.$1, 'content': c.$2, 'createdAt': at},
        ],
        'likes': <Map<String, dynamic>>[
          for (final l in likes) {'id': _id('l'), 'username': l, 'createdAt': at},
        ],
      };
    }

    _posts.addAll([
      post(giulia, 'Primo 5x5 di squat a 80 kg completato. Le gambe tremano ma ne è valsa la pena 🔥', 1, 2,
          ['mousty', 'marco_lifts'], [('mousty', 'Grande Giulia!'), ('marco_lifts', 'Sabato tocca a noi 💪')]),
      post(marco, 'Sessione push con la crew stamattina. Chi viene sabato?', 2, 20, ['giulia.fit'], [('giulia.fit', 'Io ci sono')]),
      post(_me, 'Nuovo record in panca: 72,5 kg x 8!', 3, 30, ['giulia.fit', 'marco_lifts', 'sara.runs'], []),
      post(luca, 'Primo muscle-up pulito dopo tre mesi di prove. Non mollate!', 4, 50, ['sara.runs'], []),
    ]);

    _friendships.addAll([
      {'id': 'f1', 'user': _simple(_me), 'friend': _simple(giulia), 'status': 'accepted', 'createdAt': _iso(_now)},
      {'id': 'f2', 'user': _simple(marco), 'friend': _simple(_me), 'status': 'accepted', 'createdAt': _iso(_now)},
      {
        'id': 'f3',
        'user': _simple(sara),
        'friend': _simple(_me),
        'status': 'pending',
        'createdAt': _iso(_now.subtract(const Duration(hours: 3))),
      },
    ]);
  }

  Map<String, dynamic> _workout(String id, Map<String, dynamic> owner, String name, String? description, bool isPublic,
          List<int> days, String? time, List<Map<String, dynamic>> exercises) =>
      {
        'id': id,
        'user': owner,
        'name': name,
        'description': description,
        'isPublic': isPublic,
        'dayOfWeek': days,
        'startTime': time,
        'createdAt': _iso(_now.subtract(const Duration(days: 20))),
        'workoutExercises': exercises,
        'workoutGroups': <dynamic>[],
        'workoutHistories': <dynamic>[],
      };

  Map<String, dynamic> _group(String id, String name, String workoutId, Map<String, dynamic> creator, DateTime when,
          List<Map<String, dynamic>> members) =>
      {
        'id': id,
        'name': name,
        'workoutId': workoutId,
        'createdBy': _simple(creator),
        'scheduledFor': _iso(when),
        'status': 'scheduled',
        'createdAt': _iso(_now),
        'groupMembers': members,
      };

  // ---------------------------------------------------------------- viste JSON

  String get _meName => _me['username'] as String;

  Map<String, dynamic> _page(List<dynamic> items) => {
        'results': items,
        'pageInfo': {
          'hasNext': false,
          'hasPrevious': false,
          'numberOfElements': items.length,
          'totalPages': 1,
          'currentPage': 0,
        },
        'totalCount': items.length,
      };

  Map<String, dynamic> _postView(Map<String, dynamic> p) => {
        ...p,
        'numLikes': (p['likes'] as List).length,
        'numComments': (p['comments'] as List).length,
      };

  Map<String, dynamic> _groupView(Map<String, dynamic> g) {
    final w = _workouts.firstWhere((w) => w['id'] == g['workoutId'], orElse: () => {'id': g['workoutId'], 'name': 'Scheda'});
    return {
      ...g,
      'workout': {
        'id': w['id'],
        'name': w['name'],
        'user': w['user'] == null ? null : _simple(w['user'] as Map<String, dynamic>),
        'isPublic': w['isPublic'],
        'dayOfWeek': w['dayOfWeek'],
      },
    };
  }

  bool _isFriend(String username) => _friendships.any((f) =>
      f['status'] == 'accepted' &&
      {(f['user'] as Map)['username'], (f['friend'] as Map)['username']}.containsAll([_meName, username]));

  bool _canSeeGroup(Map<String, dynamic> g) =>
      (g['createdBy'] as Map)['username'] == _meName ||
      (g['groupMembers'] as List).any((m) => (m['user'] as Map)['username'] == _meName && m['status'] == 'accepted');

  Map<String, dynamic> _ok(String message) => {'message': message, 'timestamp': _iso(DateTime.now())};

  // ---------------------------------------------------------------- rotte

  Future<dynamic> _route(RequestOptions o) async {
    final method = o.method.toUpperCase();
    final path = Uri.parse(o.path).path;
    final q = o.queryParameters;
    final body = o.data is Map ? Map<String, dynamic>.from(o.data as Map) : <String, dynamic>{};
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    final last = seg.isEmpty ? '' : seg.last;

    bool match(String m, String pattern) {
      if (m != method) return false;
      final p = pattern.split('/').where((s) => s.isNotEmpty).toList();
      if (p.length != seg.length) return false;
      for (var i = 0; i < p.length; i++) {
        if (!p[i].startsWith(':') && p[i] != seg[i]) return false;
      }
      return true;
    }

    // Auth
    if (match('POST', '/auth/login')) {
      final username = '${body['username']}'.trim();
      if (body['password'] == 'sbagliata') throw _MockError(401, 'Bad credentials');
      if (username == 'nonverificato') {
        throw _MockError(403, 'Email not verified: check your inbox for the verification code');
      }
      return {'message': 'login successful', 'result': _me, 'token': 'mock-token', 'refreshToken': 'mock-refresh'};
    }
    if (match('POST', '/auth/signup')) return _ok('Signup successful!');
    if (match('POST', '/auth/verify-otp')) {
      if (body['otp'] == '000000') throw _MockError(400, 'Invalid OTP');
      return _ok('Email verified');
    }
    if (match('POST', '/auth/send-otp') || match('POST', '/auth/send-reset-otp')) return _ok('OTP sent');
    if (match('POST', '/auth/reset-password')) {
      if (body['otp'] == '000000') throw _MockError(400, 'Invalid OTP');
      return _ok('Password reset');
    }
    if (match('GET', '/auth/profile')) return _me;
    if (match('POST', '/auth/refresh')) {
      return {'message': 'ok', 'token': 'mock-token', 'refreshToken': 'mock-refresh'};
    }
    if (match('POST', '/auth/logout')) return _ok('Logged out');

    // Utenti
    if (match('GET', '/users/search')) {
      final s = '${q['username'] ?? ''}'.toLowerCase();
      return _users.where((u) => '${u['username']}'.toLowerCase().contains(s)).map(_simple).toList();
    }
    if (match('GET', '/users/username/:u')) return _userBy(Uri.decodeComponent(last));
    if (match('GET', '/users/:id')) {
      return _users.firstWhere((u) => u['id'] == last, orElse: () => throw _MockError(404, 'Utente non trovato'));
    }
    if (match('PUT', '/users/update-profile-image')) {
      final bytes = await _fileFrom(o.data, 'imageFile');
      if (bytes != null) {
        final key = _id('img');
        uploads[key] = bytes;
        _me['image'] = '$uploadScheme$key';
      }
      return _ok('Image updated');
    }
    if (match('DELETE', '/users/me')) return _ok('Account deleted');

    // Post
    if (match('GET', '/posts')) {
      final sorted = [..._posts]..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
      return _page(sorted.map(_postView).toList());
    }
    if (match('GET', '/posts/user')) {
      return _posts.where((p) => (p['user'] as Map)['username'] == q['username']).map(_postView).toList();
    }
    if (match('GET', '/friendship/posts')) {
      return _posts.where((p) => _isFriend('${(p['user'] as Map)['username']}')).map(_postView).toList();
    }
    if (match('POST', '/posts/create')) {
      final form = o.data as FormData;
      final req = form.files.firstWhere((f) => f.key == 'request', orElse: () => throw _MockError(400, 'Richiesta non valida'));
      final json = jsonDecode(utf8.decode(await _read(req.value))) as Map<String, dynamic>;
      final bytes = await _fileFrom(form, 'imageFile');
      String? image;
      if (bytes != null) {
        final key = _id('img');
        uploads[key] = bytes;
        image = '$uploadScheme$key';
      }
      final at = _iso(DateTime.now());
      final post = {
        'id': _id('p'),
        'user': _me,
        'content': json['content'],
        'image': image,
        'createdAt': at,
        'updatedAt': at,
        'comments': <dynamic>[],
        'likes': <dynamic>[],
      };
      _posts.insert(0, post);
      return {'message': 'Post created', 'result': _postView(post)};
    }
    if (match('PUT', '/posts/update')) {
      _postById('${body['id']}')['content'] = body['content'];
      return _ok('Post updated');
    }
    if (match('DELETE', '/posts/delete/:id')) {
      _posts.remove(_postById(last));
      return _ok('Post deleted');
    }
    if (match('GET', '/posts/:id')) return _postView(_postById(last));

    // Like e commenti
    if (match('POST', '/likes/create')) {
      final post = _postById('${body['postId']}');
      final like = {'id': _id('l'), 'username': _meName, 'createdAt': _iso(DateTime.now())};
      (post['likes'] as List).add(like);
      return {'id': like['id'], 'postId': post['id'], 'user': _me, 'createdAt': like['createdAt']};
    }
    if (match('DELETE', '/likes/delete/:id')) {
      for (final p in _posts) {
        (p['likes'] as List).removeWhere((l) => l['id'] == last);
      }
      return _ok('Like removed');
    }
    if (match('POST', '/comments/create')) {
      final post = _postById('${body['postId']}');
      final c = {
        'id': _id('c'),
        'postId': post['id'],
        'username': _meName,
        'content': body['content'],
        'createdAt': _iso(DateTime.now()),
      };
      (post['comments'] as List).add(c);
      return {'message': 'Comment created', 'result': {...c, 'user': _me}};
    }
    if (match('DELETE', '/comments/:id')) {
      for (final p in _posts) {
        (p['comments'] as List).removeWhere((c) => c['id'] == last);
      }
      return _ok('Comment deleted');
    }

    // Amicizie
    if (match('GET', '/friendship')) {
      return _page(_friendships
          .where((f) =>
              f['status'] == 'accepted' &&
              ((f['user'] as Map)['username'] == _meName || (f['friend'] as Map)['username'] == _meName))
          .toList());
    }
    if (match('GET', '/friendship/requests')) {
      return _friendships
          .where((f) => f['status'] == 'pending' && (f['friend'] as Map)['username'] == _meName)
          .toList();
    }
    if (match('POST', '/friendship/create')) {
      final other = _userBy('${q['friendUsername']}');
      if (other['username'] == _meName) throw _MockError(400, 'Non puoi aggiungere te stesso');
      final exists = _friendships.any((f) =>
          {(f['user'] as Map)['username'], (f['friend'] as Map)['username']}.containsAll([_meName, other['username']]));
      if (exists) throw _MockError(409, 'Siete già amici o c\'è già una richiesta');
      _friendships.add({
        'id': _id('f'),
        'user': _simple(_me),
        'friend': _simple(other),
        'status': 'pending',
        'createdAt': _iso(DateTime.now()),
      });
      return _ok('Friend request sent!');
    }
    if (match('GET', '/friendship/accept/:id')) {
      _friendshipById(last)['status'] = 'accepted';
      return _ok('Friend request accepted!');
    }
    if (match('GET', '/friendship/reject/:id')) {
      _friendships.remove(_friendshipById(last));
      return _ok('Friend request rejected!');
    }
    if (match('GET', '/friendship/block/:id')) {
      _friendshipById(last)['status'] = 'blocked';
      return _ok('User blocked!');
    }

    // Schede
    if (match('GET', '/workouts/profile')) {
      return _workouts.where((w) => (w['user'] as Map)['username'] == _meName).toList();
    }
    if (match('GET', '/workouts')) {
      return _page(_workouts.where((w) => w['isPublic'] == true || (w['user'] as Map)['username'] == _meName).toList());
    }
    if (match('POST', '/workouts/create')) {
      final w = _workout(_id('w'), _me, '${body['name']}', body['description'] as String?, body['isPublic'] == true,
          List<int>.from(body['dayOfWeek'] as List? ?? const []), body['startTime'] as String?, []);
      w['createdAt'] = _iso(DateTime.now());
      _workouts.add(w);
      return {'message': 'Workout created', 'result': w};
    }
    if (match('PUT', '/workouts/update')) {
      final w = _workoutById('${body['id']}');
      w
        ..['name'] = body['name']
        ..['description'] = body['description']
        ..['isPublic'] = body['isPublic']
        ..['dayOfWeek'] = body['dayOfWeek'] ?? const []
        ..['startTime'] = body['startTime'];
      return _ok('Workout updated');
    }
    if (match('DELETE', '/workouts/delete/:id')) {
      _workouts.remove(_workoutById(last));
      return _ok('Workout deleted');
    }
    if (match('GET', '/workouts/:id')) return _workoutById(last);

    // Esercizi della scheda
    if (match('POST', '/workout-exercises/create') || match('PUT', '/workout-exercises/update')) {
      final w = _workoutById('${body['workoutId']}');
      final ex = _exercises.firstWhere((e) => e['id'] == body['exerciseId'], orElse: () => throw _MockError(404, 'Esercizio non trovato'));
      final list = w['workoutExercises'] as List;
      final item = {...body, 'id': body['id'] ?? _id('we'), 'exerciseName': ex['name']};
      final i = list.indexWhere((e) => e['id'] == item['id']);
      i >= 0 ? list[i] = item : list.add(item);
      return {'message': 'ok', 'result': item};
    }
    if (match('DELETE', '/workout-exercises/delete/:id')) {
      for (final w in _workouts) {
        (w['workoutExercises'] as List).removeWhere((e) => e['id'] == last);
      }
      return _ok('Exercise removed');
    }

    // Libreria esercizi
    if (match('GET', '/exercises')) {
      final visible = _exercises.where((e) => e['isPublic'] == true || (e['createdBy'] as Map)['username'] == _meName).toList()
        ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      return _page(visible);
    }
    if (match('POST', '/exercises/create')) {
      final e = {...body, 'id': _id('e'), 'createdBy': _me};
      _exercises.add(e);
      return {'message': 'Exercise created', 'result': e};
    }
    if (match('DELETE', '/exercises/delete/:id')) {
      _exercises.removeWhere((e) => e['id'] == last);
      return _ok('Exercise deleted');
    }

    // Storico
    if (match('GET', '/workout-history/user') || match('GET', '/workout-history')) {
      final sorted = [..._history]..sort((a, b) => '${b['startedAt']}'.compareTo('${a['startedAt']}'));
      return _page(sorted);
    }
    if (match('GET', '/workout-history/group/:id')) {
      return _page(_history.where((h) => h['groupId'] == last).toList());
    }
    if (match('POST', '/workout-history')) {
      final h = {...body, 'id': _id('h'), 'userId': _me['id']};
      _history.add(h);
      return {'message': 'Workout logged', 'result': h};
    }
    if (match('DELETE', '/workout-history/delete/:id')) {
      _history.removeWhere((h) => h['id'] == last);
      return _ok('History deleted');
    }

    // Gruppi
    if (match('GET', '/workout_groups')) return _page(_groups.where(_canSeeGroup).map(_groupView).toList());
    if (match('POST', '/workout_groups/create')) {
      final g = _group(_id('g'), '${body['name']}', '${body['workoutId']}', _me,
          DateTime.tryParse('${body['scheduledFor']}') ?? DateTime.now().add(const Duration(days: 1)), []);
      if (body['scheduledFor'] == null) g['scheduledFor'] = null;
      _groups.add(g);
      return {'message': 'Group created', 'result': _groupView(g)};
    }
    if (match('DELETE', '/workout_groups/delete/:id')) {
      _groups.removeWhere((g) => g['id'] == last);
      return _ok('Group deleted');
    }
    if (match('GET', '/workout_groups/:id')) return _groupView(_groupById(last));

    // Membri dei gruppi
    if (match('GET', '/group_members')) {
      return _page([
        for (final g in _groups)
          for (final m in g['groupMembers'] as List)
            if ((m['user'] as Map)['username'] == _meName) m,
      ]);
    }
    if (match('POST', '/group_members/create')) {
      final g = _groupById('${body['groupId']}');
      final u = _userBy('${body['invitedUsername']}');
      final members = g['groupMembers'] as List;
      if (members.any((m) => (m['user'] as Map)['username'] == u['username'])) {
        throw _MockError(409, '@${u['username']} è già nel gruppo');
      }
      final m = {
        'id': _id('m'),
        'workoutGroupId': g['id'],
        'user': _simple(u),
        'status': 'invited',
        'createdAt': _iso(DateTime.now()),
      };
      members.add(m);
      return {'message': 'Invited', 'result': m};
    }
    if (match('POST', '/group_members/accept-invitation/:id')) {
      _memberById(last)['status'] = 'accepted';
      return _ok('Invitation accepted');
    }
    if (match('POST', '/group_members/reject-invitation/:id') || match('DELETE', '/group_members/delete/:id')) {
      for (final g in _groups) {
        (g['groupMembers'] as List).removeWhere((m) => m['id'] == last);
      }
      return _ok('Removed');
    }

    throw _MockError(404, 'Mock: rotta non gestita $method $path');
  }

  Map<String, dynamic> _postById(String id) =>
      _posts.firstWhere((p) => p['id'] == id, orElse: () => throw _MockError(404, 'Post non trovato'));

  Map<String, dynamic> _workoutById(String id) =>
      _workouts.firstWhere((w) => w['id'] == id, orElse: () => throw _MockError(404, 'Scheda non trovata'));

  Map<String, dynamic> _groupById(String id) =>
      _groups.firstWhere((g) => g['id'] == id, orElse: () => throw _MockError(404, 'Gruppo non trovato'));

  Map<String, dynamic> _friendshipById(String id) =>
      _friendships.firstWhere((f) => f['id'] == id, orElse: () => throw _MockError(404, 'Amicizia non trovata'));

  Map<String, dynamic> _memberById(String id) {
    for (final g in _groups) {
      for (final m in g['groupMembers'] as List) {
        if (m['id'] == id) return m as Map<String, dynamic>;
      }
    }
    throw _MockError(404, 'Invito non trovato');
  }

  Future<Uint8List?> _fileFrom(Object? data, String field) async {
    if (data is! FormData) return null;
    for (final f in data.files) {
      if (f.key == field) return _read(f.value);
    }
    return null;
  }

  Future<Uint8List> _read(MultipartFile file) async {
    final chunks = await file.finalize().toList();
    return Uint8List.fromList(chunks.expand((c) => c).toList());
  }
}

class _MockError implements Exception {
  _MockError(this.status, this.message);

  final int status;
  final String message;
}
