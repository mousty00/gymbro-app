import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbro_app/core/mock/mock_backend.dart';
import 'package:gymbro_app/models/group.dart';
import 'package:gymbro_app/models/page.dart';
import 'package:gymbro_app/models/social.dart';
import 'package:gymbro_app/models/user.dart';
import 'package:gymbro_app/models/workout.dart';

void main() {
  late Dio dio;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://mock/api'))..interceptors.add(MockBackend(latency: Duration.zero, enabled: () => true));
  });

  Future<dynamic> get(String path, [Map<String, dynamic>? q]) async => (await dio.get<dynamic>(path, queryParameters: q)).data;
  Future<dynamic> post(String path, [Object? data, Map<String, dynamic>? q]) async =>
      (await dio.post<dynamic>(path, data: data, queryParameters: q)).data;

  test('login e casi di errore simulati', () async {
    final res = await post('/auth/login', {'username': 'qualsiasi', 'password': 'x'});
    expect(User.fromJson(res['result'] as Map<String, dynamic>).username, 'mousty');

    await expectLater(
      post('/auth/login', {'username': 'nonverificato', 'password': 'x'}),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 403)),
    );
    await expectLater(
      post('/auth/login', {'username': 'a', 'password': 'sbagliata'}),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
    );
  });

  test('schede: crea, aggiungi esercizio, rileggi', () async {
    final created = await post('/workouts/create', {'name': 'Test', 'isPublic': false, 'dayOfWeek': [1], 'startTime': '07:00:00'});
    final id = (created['result'] as Map)['id'] as String;
    await post('/workout-exercises/create', {'workoutId': id, 'exerciseId': 'e0', 'sets': 3, 'reps': 10, 'restSeconds': 60, 'position': 1});
    final w = Workout.fromJson(await get('/workouts/$id') as Map<String, dynamic>);
    expect(w.exercises.single.exerciseName, 'Panca piana');
    expect(w.startTime!.label, '07:00');
    final mine = (await get('/workouts/profile') as List).map((e) => Workout.fromJson(e as Map<String, dynamic>));
    expect(mine.any((x) => x.id == id), isTrue);
  });

  test('like, commento e feed amici', () async {
    final feed = PageResult.fromJson(await get('/posts') as Map<String, dynamic>, Post.fromJson);
    final target = feed.results.firstWhere((p) => p.likeBy('mousty') == null);
    final like = await post('/likes/create', {'postId': target.id, 'userId': 'u1'});
    await post('/comments/create', {'postId': target.id, 'content': 'Forza!'});
    final after = Post.fromJson(await get('/posts/${target.id}') as Map<String, dynamic>);
    expect(after.numLikes, target.numLikes + 1);
    expect(after.likeBy('mousty')?.id, like['id']);
    expect(after.comments.last.content, 'Forza!');

    final friends = (await get('/friendship/posts') as List).map((e) => Post.fromJson(e as Map<String, dynamic>));
    expect(friends.every((p) => p.user.username != 'luca.cali'), isTrue);
  });

  test('richiesta di amicizia e invito al gruppo accettati', () async {
    final requests = (await get('/friendship/requests') as List).map((e) => Friendship.fromJson(e as Map<String, dynamic>)).toList();
    expect(requests.single.user.username, 'sara.runs');
    await get('/friendship/accept/${requests.single.id}');
    expect(await get('/friendship/requests'), isEmpty);

    final invites = PageResult.fromJson(await get('/group_members') as Map<String, dynamic>, GroupMember.fromJson)
        .results
        .where((m) => m.status == GroupMemberStatus.invited)
        .toList();
    expect(invites.single.groupName, isNotNull);
    await post('/group_members/accept-invitation/${invites.single.id}');
    final groups = PageResult.fromJson(await get('/workout_groups') as Map<String, dynamic>, WorkoutGroup.fromJson).results;
    expect(groups.any((g) => g.id == invites.single.groupId), isTrue);
  });

  test('post con foto in multipart', () async {
    final form = FormData()
      ..files.add(MapEntry('request', MultipartFile.fromString('{"userId":"u1","content":"Nuovo"}')))
      ..files.add(MapEntry('imageFile', MultipartFile.fromBytes([1, 2, 3], filename: 'a.jpg')));
    final res = await post('/posts/create', form);
    final p = Post.fromJson(res['result'] as Map<String, dynamic>);
    expect(p.image, startsWith(MockBackend.uploadScheme));
    expect(MockBackend.uploads[p.image!.substring(MockBackend.uploadScheme.length)], [1, 2, 3]);
  });
}
