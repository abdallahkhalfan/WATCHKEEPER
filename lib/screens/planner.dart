import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/services.dart';

class PlannerPage extends StatelessWidget {
  const PlannerPage({super.key});

  Future<void> add(BuildContext context) async {
    final title = TextEditingController();
    final note = TextEditingController();
    String type = 'Task';
    String category = 'Personal';
    DateTime day = DateTime.now();
    TimeOfDay time = TimeOfDay.now();
    int before = 10;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                0,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Create', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Task', label: Text('Task'), icon: Icon(Icons.check_circle_outline)),
                        ButtonSegment(value: 'Event', label: Text('Event'), icon: Icon(Icons.event_outlined)),
                      ],
                      selected: {type},
                      onSelectionChanged: (value) => setSheetState(() => type = value.first),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'What should I keep watch over?'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: note,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes / checklist / what to carry'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items: const ['Personal', 'Work', 'Travel', 'Prayer', 'Shopping', 'Family', 'Health']
                          .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setSheetState(() => category = value);
                      },
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final selected = await showDatePicker(
                                context: context,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                                initialDate: day,
                              );
                              if (selected != null) setSheetState(() => day = selected);
                            },
                            icon: const Icon(Icons.calendar_month),
                            label: Text(DateFormat('d MMM y').format(day)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final selected = await showTimePicker(context: context, initialTime: time);
                              if (selected != null) setSheetState(() => time = selected);
                            },
                            icon: const Icon(Icons.schedule),
                            label: Text(time.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: before,
                      items: const [0, 5, 10, 15, 30, 60, 120]
                          .map((x) => DropdownMenuItem(value: x, child: Text(x == 0 ? 'At the time' : '$x min before')))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setSheetState(() => before = value);
                      },
                      decoration: const InputDecoration(labelText: 'Reminder'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (title.text.trim().isEmpty) return;
                          final when = DateTime(day.year, day.month, day.day, time.hour, time.minute);
                          final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

                          await DB.planner.add({
                            'type': type,
                            'title': title.text.trim(),
                            'note': note.text.trim(),
                            'category': category,
                            'when': Timestamp.fromDate(when),
                            'before': before,
                            'notificationId': notificationId,
                            'done': false,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          await Alerts.i.schedule(notificationId, title.text.trim(), when, before);

                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('Save & keep watch'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    title.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => add(context),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DB.planner.orderBy('when').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          return CustomScrollView(
            slivers: [
              const SliverAppBar(
                backgroundColor: Colors.transparent,
                floating: true,
                title: Text('Planner', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26)),
              ),
              if (docs.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Your planner is clear.\nTap Create to add your life.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 18),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 5, 12, 100),
                  sliver: SliverList.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final when = (data['when'] as Timestamp).toDate();

                      return Dismissible(
                        key: ValueKey(doc.id),
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onDismissed: (_) => doc.reference.delete(),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Checkbox(
                              value: data['done'] == true,
                              onChanged: (value) => doc.reference.update({'done': value}),
                            ),
                            title: Text(
                              (data['title'] ?? '').toString(),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              '${data['category']}  •  ${DateFormat('EEE d MMM • h:mm a').format(when)}\n${data['note'] ?? ''}',
                            ),
                            isThreeLine: (data['note'] ?? '').toString().isNotEmpty,
                            trailing: Icon(data['type'] == 'Event' ? Icons.event : Icons.task_alt),
                          ),
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
