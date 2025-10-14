import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_repo.dart';
import '../data/message_model.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String subject;

  const ChatPage({super.key, required this.subject});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

// dart
class _ChatPageState extends ConsumerState<ChatPage> {
  final ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final msgsAsync = ref.watch(messagesProvider(widget.subject));
    final sending = ref.watch(chatRepoProvider.select((c) => c.isSending));

    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'subject-${widget.subject}',
          child: Text(widget.subject),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: msgsAsync.when(
                  data: (msgsDesc) {
                    final list = msgsDesc.reversed.toList();
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final m = list[i];
                        final isUser = m.role == 'user';
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(maxWidth: 640),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Colors.indigo.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Text(m.content),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          minLines: 1,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: 'Ask a question…',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: sending
                            ? null
                            : () async {
                                final q = ctrl.text.trim();
                                if (q.isEmpty) return;
                                try {
                                  ctrl.clear();
                                  FocusScope.of(context).unfocus();
                                  ref.read(chatRepoProvider).sending(true);
                                  await ref.read(chatRepoProvider).send(widget.subject, q);
                                } finally {
                                  ref.read(chatRepoProvider).sending(false);
                                }
                              },
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          sending ? Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.transparent,
            ),
          ) : SizedBox.shrink(),
        ],
      ),
    );
  }
}
