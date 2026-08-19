import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/services.dart';
import '../widgets/scenery_hero.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.jump});

  final void Function(int) jump;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'WATCHKEEPER',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                  IconButton(
                    onPressed: Alerts.i.test,
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const SceneryHero(),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _Quick(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Ask Keeper',
                      sub: 'Talk naturally',
                      tap: () => jump(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Quick(
                      icon: Icons.photo_library_outlined,
                      label: 'Memory',
                      sub: 'Capture a moment',
                      tap: () => jump(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Under watch', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: DB.planner.orderBy('when').limit(4).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: LinearProgressIndicator(),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.auto_awesome),
                        title: Text('Your day is clear'),
                        subtitle: Text('Add something from Planner and I’ll keep watch.'),
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final stamp = data['when'];
                      final when = stamp is Timestamp ? stamp.toDate().toLocal() : null;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(data['type'] == 'Event' ? Icons.event : Icons.check_rounded),
                          ),
                          title: Text((data['title'] ?? '').toString()),
                          subtitle: Text(when == null ? '' : when.toString().substring(0, 16)),
                          trailing: data['done'] == true ? const Icon(Icons.done_all) : null,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.sub, required this.tap});

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback tap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 18),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              Text(sub, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
