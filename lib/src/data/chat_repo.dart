import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'messages_repository.dart';
import 'message_model.dart';

final messagesRepoProvider = Provider<MessagesRepository>(
  (_) => MessagesRepository(),
);
final apiProvider = Provider<ApiClient>((_) => ApiClient.auto());

final messagesProvider = StreamProvider.family<List<MessageModel>, String>((
  ref,
  subject,
) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final repo = ref.read(messagesRepoProvider);
  return repo.watchLatest(uid, subject);
});

class ChatRepo extends ChangeNotifier {
  final MessagesRepository repo;
  final Dio http;
  bool isSending = false;
  ChatRepo(this.repo, this.http);

  Future<String> send(String subject, String question) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await repo.insertMessage(
      MessageModel(
        uid: uid,
        subject: subject,
        role: 'user',
        content: question,
        createdAt: DateTime.now(),
      ),
    );

    final res = await http.post(
      '/v1/chat',
      data: {
        'subject': subject,
        'message': question,
        'history': [], // keeping server context minimal; we store local history
      },
    );
    final reply = (res.data['reply'] as String?) ?? '';

    await repo.insertMessage(
      MessageModel(
        uid: uid,
        subject: subject,
        role: 'model',
        content: reply,
        createdAt: DateTime.now(),
      ),
    );

    return reply;
  }

  sending(bool isSending) {
    this.isSending = isSending;
    notifyListeners();
  }

  refresh() {
    notifyListeners();
  }
}

final chatRepoProvider = Provider<ChatRepo>((ref) {
  final repo = ref.read(messagesRepoProvider);
  final api = ref.read(apiProvider).dio;
  return ChatRepo(repo, api);
});
