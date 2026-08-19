import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/services.dart';

class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});

  String _conversationId(String a, String b) => a.compareTo(b) < 0 ? '$a-$b' : '$b-$a';

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').limit(50).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load users.'));
          }
          final users = (snapshot.data?.docs ?? []).where((x) => x.id != me.uid).toList();

          return CustomScrollView(
            slivers: [
              const SliverAppBar(
                backgroundColor: Colors.transparent,
                floating: true,
                title: Text('Connect', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26)),
              ),
              if (users.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No other WATCHKEEPER users yet.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverList.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final userDoc = users[index];
                      final data = userDoc.data();
                      final name = (data['name'] ?? 'WATCHKEEPER user').toString();

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(name.isEmpty ? 'W' : name.characters.first.toUpperCase()),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text((data['email'] ?? '').toString()),
                          trailing: const Icon(Icons.chat_bubble_outline),
                          onTap: () async {
                            final id = _conversationId(me.uid, userDoc.id);
                            await DB.conversations.doc(id).set({
                              'members': [me.uid, userDoc.id],
                              'memberNames': {
                                me.uid: me.displayName ?? me.email ?? 'You',
                                userDoc.id: data['name'] ?? data['email'] ?? 'User',
                              },
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(id: id, title: name),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.id, required this.title});

  final String id;
  final String title;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    _text.clear();

    final conversation = DB.conversations.doc(widget.id);
    await conversation.collection('messages').add({
      'senderId': DB.uid,
      'text': value,
      'at': FieldValue.serverTimestamp(),
      'type': 'text',
    });
    await conversation.update({
      'lastMessage': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversation = DB.conversations.doc(widget.id);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: conversation
                  .collection('messages')
                  .orderBy('at', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final mine = data['senderId'] == DB.uid;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
                        decoration: BoxDecoration(
                          color: mine ? Theme.of(context).colorScheme.primary : Colors.white10,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text((data['text'] ?? '').toString()),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Message…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
