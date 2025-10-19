// dart
import 'package:ai_teacher01/src/data/chat_repo.dart';
import 'package:ai_teacher01/src/data/subjects_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SubjectGridPage extends ConsumerStatefulWidget {
  const SubjectGridPage({super.key});

  @override
  ConsumerState<SubjectGridPage> createState() => _SubjectGridPageState();
}

class _SubjectGridPageState extends ConsumerState<SubjectGridPage> {
  late final TextEditingController _searchController;
  final List<String> _subjects = [];
  bool _isGrid = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // load subjects from db
    final uid = FirebaseAuth.instance.currentUser!.uid;
    ref.read(subjectsRepoProvider).watch(uid).listen((list) {
      setState(() {
        _subjects.clear();
        _subjects.addAll(list);
      });
    });
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final filtered = query.isEmpty
        ? _subjects
        : _subjects.where((s) => s.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subjects'),
        actions: [
          IconButton(
            icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view),
            tooltip: _isGrid ? 'Switch to list' : 'Switch to grid',
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Subject',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isGrid
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.6,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      return GestureDetector(
                        onTap: () => context.push('/chat/$s'),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.indigo.shade400,
                                Colors.indigo.shade700,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      return ListTile(
                        leading: Hero(
                          tag: 'subject-$s',
                          child: CircleAvatar(
                            backgroundColor: Colors.indigo,
                            child: Text(
                              s.isNotEmpty ? s[0] : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        title: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => context.push('/chat/$s'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              final TextEditingController subjectController =
                  TextEditingController();
              return AlertDialog(
                title: const Text('Add Subject'),
                content: TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(hintText: 'Subject Name'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final text = subjectController.text.trim();
                      if (text.isNotEmpty) {
                        // subjects should be added to db and fetched from there
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                        final uid = FirebaseAuth.instance.currentUser!.uid;
                        final id = await ref
                            .watch(subjectsRepoProvider)
                            .insertSubject(uid, text);
                        if (id != -1) {
                          setState(() {
                            _subjects.insert(0, text);
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Subject "$text" already exists.'),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
