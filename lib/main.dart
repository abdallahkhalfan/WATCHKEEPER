import 'package:flutter/material.dart';

void main() {
  runApp(const WatchkeeperApp());
}

class WatchkeeperApp extends StatelessWidget {
  const WatchkeeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WATCHKEEPER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const WatchkeeperHome(),
    );
  }
}

class WatchkeeperHome extends StatefulWidget {
  const WatchkeeperHome({super.key});

  @override
  State<WatchkeeperHome> createState() => _WatchkeeperHomeState();
}

class _WatchkeeperHomeState extends State<WatchkeeperHome> {
  final List<Reminder> reminders = [];

  void _addReminder() {
    final titleController = TextEditingController();
    final itemController = TextEditingController();
    final List<String> items = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Create Watch',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Reminder or Event',
                        hintText: 'Example: Go to work',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: itemController,
                            decoration: const InputDecoration(
                              labelText: 'Essential item',
                              hintText: 'Phone, keys, water...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: () {
                            if (itemController.text.trim().isNotEmpty) {
                              setModalState(() {
                                items.add(itemController.text.trim());
                                itemController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    ...items.map(
                      (item) => CheckboxListTile(
                        value: false,
                        title: Text(item),
                        onChanged: (_) {},
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Watch'),
                      onPressed: () {
                        if (titleController.text.trim().isNotEmpty) {
                          setState(() {
                            reminders.add(
                              Reminder(
                                title: titleController.text.trim(),
                                items: List.from(items),
                              ),
                            );
                          });

                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChecklist(Reminder reminder) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ChecklistScreen(reminder: reminder);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WATCHKEEPER',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Your personal departure buddy',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReminder,
        icon: const Icon(Icons.add),
        label: const Text('New Watch'),
      ),

      body: reminders.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 90,
                      color: Colors.indigo,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Your personal reminder buddy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Create a Watch for work, weddings, baby showers, travel, or any important event.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'WATCHKEEPER will help you remember your essential items before you leave.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reminders.length,
              itemBuilder: (context, index) {
                final reminder = reminders[index];

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.watch_later_outlined),
                    ),
                    title: Text(
                      reminder.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${reminder.items.length} things to check',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showChecklist(reminder),
                  ),
                );
              },
            ),
    );
  }
}

class Reminder {
  final String title;
  final List<String> items;

  Reminder({
    required this.title,
    required this.items,
  });
}

class ChecklistScreen extends StatefulWidget {
  final Reminder reminder;

  const ChecklistScreen({
    super.key,
    required this.reminder,
  });

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late List<bool> checked;

  @override
  void initState() {
    super.initState();
    checked = List.generate(
      widget.reminder.items.length,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed =
        checked.where((item) => item).length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.reminder.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            '$completed of ${widget.reminder.items.length} items ready',
          ),

          const SizedBox(height: 15),

          ...List.generate(
            widget.reminder.items.length,
            (index) => CheckboxListTile(
              value: checked[index],
              title: Text(widget.reminder.items[index]),
              onChanged: (value) {
                setState(() {
                  checked[index] = value ?? false;
                });
              },
            ),
          ),

          const SizedBox(height: 15),

          if (completed == widget.reminder.items.length)
            const Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 50,
                ),
                SizedBox(height: 8),
                Text(
                  'Everything is ready. You are good to go!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else
            const Text(
              'WATCHKEEPER: Check everything before leaving.',
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
