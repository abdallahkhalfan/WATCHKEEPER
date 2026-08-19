import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await Alerts.instance.init();

  runApp(const WatchkeeperApp());
}

// ============================================================
// NOTIFICATIONS
// ============================================================

class Alerts {
  Alerts._();

  static final Alerts instance = Alerts._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // timezone package will use its default if device timezone lookup fails.
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await plugin.initialize(settings: settings);

    final android =
        plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();
  }

  Future<void> test() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'watchkeeper_reminders',
        'WATCHKEEPER Reminders',
        channelDescription: 'Tasks, events and WATCHKEEPER reminders',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await plugin.show(
      id: 999,
      title: 'WATCHKEEPER',
      body: 'Notifications are working.',
      notificationDetails: details,
    );
  }

  Future<void> schedule({
    required int id,
    required String title,
    required DateTime when,
    required int minutesBefore,
  }) async {
    final notificationTime =
        when.subtract(Duration(minutes: minutesBefore));

    if (notificationTime.isBefore(DateTime.now())) {
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'watchkeeper_reminders',
        'WATCHKEEPER Reminders',
        channelDescription: 'Tasks, events and WATCHKEEPER reminders',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    final scheduled = tz.TZDateTime.from(notificationTime, tz.local);

    await plugin.zonedSchedule(
      id: id,
      title: 'WATCHKEEPER',
      body: title,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) async {
    await plugin.cancel(id: id);
  }
}

// ============================================================
// APP
// ============================================================

class WatchkeeperApp extends StatefulWidget {
  const WatchkeeperApp({super.key});

  @override
  State<WatchkeeperApp> createState() => _WatchkeeperAppState();
}

class _WatchkeeperAppState extends State<WatchkeeperApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void changeTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8C7AE6),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WATCHKEEPER',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
      ),
      home: AuthGate(
        onThemeChanged: changeTheme,
      ),
    );
  }
}

// ============================================================
// AUTHENTICATION
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.onThemeChanged,
  });

  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data == null) {
          return const LoginScreen();
        }

        return HomeScreen(
          onThemeChanged: onThemeChanged,
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool register = false;
  bool busy = false;
  String error = '';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => error = 'Enter your email and password.');
      return;
    }

    setState(() {
      busy = true;
      error = '';
    });

    try {
      if (register) {
        final result =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final name = nameController.text.trim();

        if (name.isNotEmpty) {
          await result.user?.updateDisplayName(name);
        }

        if (result.user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(result.user!.uid)
              .set({
            'name': name,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? 'Authentication failed.';
      });
    } catch (e) {
      setState(() {
        error = 'Something went wrong: $e';
      });
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage(context, 'Enter your email first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        showMessage(context, 'Password reset email sent.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showMessage(context, e.message ?? 'Could not send reset email.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.tertiary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'WATCHKEEPER',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Remember more • Miss less • Stay connected',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  if (register) ...[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),

                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : submit,
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                register
                                    ? 'Create WATCHKEEPER account'
                                    : 'Sign in',
                              ),
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() {
                              register = !register;
                              error = '';
                            });
                          },
                    child: Text(
                      register
                          ? 'Already registered? Sign in'
                          : 'Create WATCHKEEPER account',
                    ),
                  ),

                  if (!register)
                    TextButton(
                      onPressed: resetPassword,
                      child: const Text('Forgot password?'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onThemeChanged,
  });

  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardPage(),
      const TasksPage(),
      const EventsPage(),
      MorePage(onThemeChanged: widget.onThemeChanged),
    ];

    return Scaffold(
      body: SafeArea(child: pages[page]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (value) {
          setState(() => page = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
      floatingActionButton: page == 1 || page == 2
          ? FloatingActionButton.extended(
              onPressed: () {
                showCreateItem(
                  context,
                  initialType: page == 1 ? 'Task' : 'Event',
                );
              },
              icon: const Icon(Icons.add),
              label: Text(page == 1 ? 'New task' : 'New event'),
            )
          : null,
    );
  }
}

// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'WATCHKEEPER',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          user?.displayName?.isNotEmpty == true
              ? 'Hello, ${user!.displayName}'
              : 'Your personal watchkeeper',
        ),
        const SizedBox(height: 24),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_rounded, size: 42),
                const SizedBox(height: 14),
                Text(
                  'Stay prepared',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create tasks and events and WATCHKEEPER will help you remember what matters.',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _DashboardButton(
                icon: Icons.add_task,
                label: 'Add task',
                onTap: () {
                  showCreateItem(context, initialType: 'Task');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardButton(
                icon: Icons.event,
                label: 'Add event',
                onTap: () {
                  showCreateItem(context, initialType: 'Event');
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        Text(
          'Upcoming',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 10),

        const UpcomingItems(),
      ],
    );
  }
}

class _DashboardButton extends StatelessWidget {
  const _DashboardButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 20,
          ),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpcomingItems extends StatelessWidget {
  const UpcomingItems({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('items')
          .orderBy('when')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load upcoming items.');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final stamp = data['when'];

          if (stamp is! Timestamp) return false;

          return stamp.toDate().isAfter(
                DateTime.now().subtract(const Duration(minutes: 1)),
              );
        }).toList();

        if (docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nothing upcoming. Add a task or event.',
              ),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            return ItemTile(
              document: doc,
            );
          }).toList(),
        );
      },
    );
  }
}

// ============================================================
// TASKS
// ============================================================

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ItemListPage(
      title: 'Tasks',
      subtitle: 'Things WATCHKEEPER should remember for you',
      type: 'Task',
      emptyMessage: 'No tasks yet.',
    );
  }
}

// ============================================================
// EVENTS
// ============================================================

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ItemListPage(
      title: 'Events',
      subtitle: 'Appointments, work, family and important dates',
      type: 'Event',
      emptyMessage: 'No events yet.',
    );
  }
}

// ============================================================
// ITEM LIST
// ============================================================

class ItemListPage extends StatelessWidget {
  const ItemListPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.emptyMessage,
  });

  final String title;
  final String subtitle;
  final String type;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('items')
        .where('type', isEqualTo: type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(subtitle),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Unable to load $title.'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final docs = snapshot.data!.docs.toList();

              docs.sort((a, b) {
                final aWhen = a.data()['when'];
                final bWhen = b.data()['when'];

                if (aWhen is! Timestamp || bWhen is! Timestamp) {
                  return 0;
                }

                return aWhen.compareTo(bWhen);
              });

              if (docs.isEmpty) {
                return Center(child: Text(emptyMessage));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  return ItemTile(document: docs[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ITEM TILE
// ============================================================

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.document,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  Future<void> deleteItem(BuildContext context) async {
    final data = document.data();
    final notificationId = data['notificationId'];

    if (notificationId is int) {
      await Alerts.instance.cancel(notificationId);
    }

    await document.reference.delete();

    if (context.mounted) {
      showMessage(context, 'Deleted.');
    }
  }

  Future<void> toggleDone(bool value) async {
    await document.reference.update({
      'done': value,
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = document.data();

    final title = data['title']?.toString() ?? 'Untitled';
    final note = data['note']?.toString() ?? '';
    final category = data['category']?.toString() ?? 'Personal';
    final done = data['done'] == true;

    DateTime? when;

    final stamp = data['when'];

    if (stamp is Timestamp) {
      when = stamp.toDate();
    }

    final dateText = when == null
        ? ''
        : DateFormat('EEE, d MMM y • h:mm a').format(when);

    return Card(
      child: ListTile(
        leading: Checkbox(
          value: done,
          onChanged: (value) {
            toggleDone(value ?? false);
          },
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dateText.isNotEmpty) Text(dateText),
            Text(category),
            if (note.isNotEmpty) Text(note),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => deleteItem(context),
        ),
      ),
    );
  }
}

// ============================================================
// CREATE TASK / EVENT
// ============================================================

Future<void> showCreateItem(
  BuildContext context, {
  required String initialType,
}) async {
  final titleController = TextEditingController();
  final noteController = TextEditingController();

  String type = initialType;
  String category = 'Personal';
  int minutesBefore = 10;

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create $type',
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 16),

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'Task',
                        label: Text('Task'),
                        icon: Icon(Icons.check_circle_outline),
                      ),
                      ButtonSegment<String>(
                        value: 'Event',
                        label: Text('Event'),
                        icon: Icon(Icons.event),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (selection) {
                      setSheetState(() {
                        type = selection.first;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'What should WATCHKEEPER remember?',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      'Personal',
                      'Work',
                      'Travel',
                      'Prayer',
                      'Shopping',
                      'Family',
                      'Health',
                      'Event',
                    ].map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => category = value);
                      }
                    },
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes / checklist / what to carry',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            DateFormat('d MMM y').format(selectedDate),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
                            );

                            if (date != null) {
                              setSheetState(() {
                                selectedDate = date;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.schedule),
                          label: Text(selectedTime.format(context)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );

                            if (time != null) {
                              setSheetState(() {
                                selectedTime = time;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<int>(
                    value: minutesBefore,
                    decoration: const InputDecoration(
                      labelText: 'Reminder',
                      border: OutlineInputBorder(),
                    ),
                    items: const [0, 5, 10, 15, 30, 60, 120]
                        .map(
                          (minutes) => DropdownMenuItem(
                            value: minutes,
                            child: Text(
                              minutes == 0
                                  ? 'At the time'
                                  : '$minutes minutes before',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() {
                          minutesBefore = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.notifications_active),
                      label: Text('Save $type & reminder'),
                      onPressed: () async {
                        final title = titleController.text.trim();

                        if (title.isEmpty) {
                          showMessage(context, 'Enter a title.');
                          return;
                        }

                        final when = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        final id = DateTime.now()
                            .millisecondsSinceEpoch
                            .remainder(2147483647);

                        final user = FirebaseAuth.instance.currentUser;

                        if (user == null) return;

                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('items')
                              .add({
                            'type': type,
                            'title': title,
                            'note': noteController.text.trim(),
                            'category': category,
                            'when': Timestamp.fromDate(when),
                            'minutesBefore': minutesBefore,
                            'notificationId': id,
                            'done': false,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          await Alerts.instance.schedule(
                            id: id,
                            title: title,
                            when: when,
                            minutesBefore: minutesBefore,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showMessage(
                              context,
                              'Could not save: $e',
                            );
                          }
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  noteController.dispose();
}

// ============================================================
// MORE / SETTINGS
// ============================================================

class MorePage extends StatefulWidget {
  const MorePage({
    super.key,
    required this.onThemeChanged,
  });

  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  double? homeLat;
  double? homeLng;

  String contactName = '';
  String contactPhone = '';

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      homeLat = prefs.getDouble('homeLat');
      homeLng = prefs.getDouble('homeLng');
      contactName = prefs.getString('contactName') ?? '';
      contactPhone = prefs.getString('contactPhone') ?? '';
    });
  }

  Future<void> markHome() async {
    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showMessage(
            context,
            'Please enable Location permission.',
          );
        }
        return;
      }

      final enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        if (mounted) {
          showMessage(context, 'Please turn on GPS.');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble('homeLat', position.latitude);
      await prefs.setDouble('homeLng', position.longitude);

      if (!mounted) return;

      setState(() {
        homeLat = position.latitude;
        homeLng = position.longitude;
      });

      showMessage(context, 'Home safe zone marked.');
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Could not mark home: $e');
      }
    }
  }

  Future<void> configureTrustedContact() async {
    final nameController = TextEditingController(text: contactName);
    final phoneController = TextEditingController(text: contactPhone);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Trusted contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();

                await prefs.setString(
                  'contactName',
                  nameController.text.trim(),
                );

                await prefs.setString(
                  'contactPhone',
                  phoneController.text.trim(),
                );

                if (!mounted) return;

                setState(() {
                  contactName = nameController.text.trim();
                  contactPhone = phoneController.text.trim();
                });

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> callTrustedContact() async {
    if (contactPhone.isEmpty) {
      showMessage(context, 'Set your trusted contact first.');
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: contactPhone,
    );

    if (!await launchUrl(uri)) {
      if (mounted) {
        showMessage(context, 'Could not open phone dialer.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'More',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const Text(
          'Safety, appearance and account settings',
        ),

        const SizedBox(height: 20),

        Card(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(
                  user?.displayName?.isNotEmpty == true
                      ? user!.displayName!
                      : 'WATCHKEEPER user',
                ),
                subtitle: Text(user?.email ?? ''),
              ),

              const Divider(height: 1),

              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Mark Home now'),
                subtitle: Text(
                  homeLat == null
                      ? 'Home safe zone not configured'
                      : 'Home safe zone configured',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: markHome,
              ),

              ListTile(
                leading: const Icon(Icons.notification_add),
                title: const Text('Test notification'),
                onTap: Alerts.instance.test,
              ),

              ListTile(
                leading: const Icon(Icons.contact_phone),
                title: const Text('Trusted contact'),
                subtitle: Text(
                  contactPhone.isEmpty
                      ? 'Not configured'
                      : '$contactName • $contactPhone',
                ),
                onTap: configureTrustedContact,
              ),

              if (contactPhone.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.call),
                  title: const Text('Call trusted contact'),
                  onTap: callTrustedContact,
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Auto'),
                      onPressed: () {
                        widget.onThemeChanged(ThemeMode.system);
                      },
                    ),
                    ActionChip(
                      label: const Text('Light'),
                      onPressed: () {
                        widget.onThemeChanged(ThemeMode.light);
                      },
                    ),
                    ActionChip(
                      label: const Text('Dark'),
                      onPressed: () {
                        widget.onThemeChanged(ThemeMode.dark);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.cloud_done),
                title: Text('Firebase'),
                subtitle: Text(
                  'Authentication and Cloud Firestore connected',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        const Center(
          child: Text(
            'WATCHKEEPER 4',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// UTILITIES
// ============================================================

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message)),
    );
}
