import 'package:flutter/material.dart';

void main() {
  runApp(const WatchkeeperApp());
}

class WatchkeeperApp extends StatelessWidget {
  const WatchkeeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WATCHKEEPER',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B5CE2),
        ),
        fontFamily: 'sans',
      ),
      home: const WatchkeeperHome(),
    );
  }
}

class Watch {
  String title;
  String category;
  String time;
  String location;
  List<String> items;

  Watch({
    required this.title,
    required this.category,
    required this.time,
    required this.location,
    required this.items,
  });
}

class WatchkeeperHome extends StatefulWidget {
  const WatchkeeperHome({super.key});

  @override
  State<WatchkeeperHome> createState() => _WatchkeeperHomeState();
}

class _WatchkeeperHomeState extends State<WatchkeeperHome> {
  int selectedIndex = 0;

  final List<Watch> watches = [
    Watch(
      title: 'Morning Work',
      category: 'WORK',
      time: 'Leave at 7:30 AM',
      location: 'Home Safe Zone',
      items: ['Phone', 'Keys', 'Wallet', 'Laptop'],
    ),
    Watch(
      title: 'Travel Watch',
      category: 'TRAVEL',
      time: 'Prepare before departure',
      location: 'Home',
      items: ['Passport', 'Phone', 'Wallet', 'Tickets'],
    ),
  ];

  final List<bool> checkedItems = [true, true, false, true];

  void addWatch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateWatchScreen(
          onSave: (watch) {
            setState(() {
              watches.add(watch);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildHome(),
      buildWatches(),
      buildActivity(),
      buildProfile(),
    ];

    return Scaffold(
      body: SafeArea(
        child: pages[selectedIndex],
      ),
      floatingActionButton: selectedIndex == 0 || selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: addWatch,
              backgroundColor: const Color(0xFF5B5CE2),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Watch'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        height: 76,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Watches',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget buildHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6C63FF),
                      Color(0xFF3E8EED),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WATCHKEEPER',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your personal departure buddy',
                      style: TextStyle(
                        color: Color(0xFF777B8A),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedIndex = 3;
                  });
                },
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF5B5CE2),
                  Color(0xFF7C4DFF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5B5CE2).withOpacity(.25),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.radar, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'WATCH MODE ACTIVE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'You are protected.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'WATCHKEEPER is ready to remind you about your important items before you leave.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () {
                    showWatchModeDialog();
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Open Watch Mode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF5B5CE2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Departure check',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Morning Work • 7:30 AM',
            style: TextStyle(color: Color(0xFF777B8A)),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Column(
              children: [
                for (int i = 0; i < 4; i++)
                  CheckboxListTile(
                    value: checkedItems[i],
                    onChanged: (value) {
                      setState(() {
                        checkedItems[i] = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      ['Phone', 'Keys', 'Wallet', 'Laptop'][i],
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: checkedItems[i]
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    secondary: Icon(
                      [
                        Icons.phone_android,
                        Icons.key,
                        Icons.account_balance_wallet,
                        Icons.laptop,
                      ][i],
                      color: const Color(0xFF5B5CE2),
                    ),
                  ),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '3 of 4 items ready',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          for (int i = 0; i < checkedItems.length; i++) {
                            checkedItems[i] = true;
                          }
                        });
                      },
                      child: const Text('Complete'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Quick actions',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: quickAction(
                  Icons.home_work_outlined,
                  'Safe Zone',
                  'Set home area',
                  () {
                    showFeatureDialog(
                      'Home Safe Zone',
                      'Your Safe Zone helps WATCHKEEPER know when you are leaving home. Location and geofencing can be connected in the next upgrade.',
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: quickAction(
                  Icons.person_add_alt_1_outlined,
                  'Emergency',
                  'Add contact',
                  () {
                    showEmergencyDialog();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your watches',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedIndex = 1;
                  });
                },
                child: const Text('See all'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ...watches.take(2).map(
            (watch) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: watchCard(watch),
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFECEBFF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 40,
                  color: Color(0xFF5B5CE2),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today’s objective',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Complete your departure checklist before leaving.',
                        style: TextStyle(
                          color: Color(0xFF666A7A),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWatches() {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.shield, color: Color(0xFF5B5CE2)),
                SizedBox(width: 10),
                Text(
                  'My Watches',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: watches.isEmpty
                ? const Center(
                    child: Text('No watches yet'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: watches.length,
                    itemBuilder: (context, index) {
                      final watch = watches[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: watchCard(
                          watch,
                          onDelete: () {
                            setState(() {
                              watches.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildActivity() {
    final activities = [
      ['Today', 'Morning Work watch activated', Icons.play_circle],
      ['Today', 'Phone confirmed', Icons.phone_android],
      ['Today', 'Keys confirmed', Icons.key],
      ['Yesterday', 'Travel Watch created', Icons.flight_takeoff],
      ['Yesterday', 'Safe Zone configured', Icons.home],
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Activity',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your preparation history',
            style: TextStyle(color: Color(0xFF777B8A)),
          ),
          const SizedBox(height: 28),
          ...activities.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEBFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      activity[2] as IconData,
                      color: const Color(0xFF5B5CE2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity[1] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity[0] as String,
                          style: const TextStyle(
                            color: Color(0xFF777B8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProfile() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Profile & Settings',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: cardDecoration(),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xFF5B5CE2),
                  child: Icon(
                    Icons.person,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WATCHKEEPER User',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Personal departure protection',
                        style: TextStyle(
                          color: Color(0xFF777B8A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          settingTile(
            Icons.location_on_outlined,
            'Home Safe Zone',
            'Configure your home location',
          ),
          settingTile(
            Icons.notifications_outlined,
            'Notifications',
            'Departure reminders and alerts',
          ),
          settingTile(
            Icons.contacts_outlined,
            'Emergency Contacts',
            'People to notify if needed',
          ),
          settingTile(
            Icons.security_outlined,
            'Privacy & Security',
            'Manage your data and permissions',
          ),
          settingTile(
            Icons.palette_outlined,
            'Appearance',
            'Customize WATCHKEEPER',
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'WATCHKEEPER • Your personal reminder buddy',
              style: TextStyle(
                color: Color(0xFF777B8A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget watchCard(Watch watch, {VoidCallback? onDelete}) {
    IconData icon = Icons.shield_outlined;

    if (watch.category == 'TRAVEL') {
      icon = Icons.flight_takeoff;
    } else if (watch.category == 'WORK') {
      icon = Icons.business_center_outlined;
    } else if (watch.category == 'FAMILY') {
      icon = Icons.family_restroom;
    } else if (watch.category == 'EVENT') {
      icon = Icons.event;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFFECEBFF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF5B5CE2),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: () {
                showWatchDetails(watch);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    watch.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    watch.time,
                    style: const TextStyle(
                      color: Color(0xFF777B8A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${watch.items.length} protected items',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5B5CE2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
            )
          else
            const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  Widget quickAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: const Color(0xFF5B5CE2),
              size: 30,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF777B8A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget settingTile(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDecoration(),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFF5B5CE2),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          showFeatureDialog(title, subtitle);
        },
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.05),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  void showWatchModeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.radar, color: Color(0xFF5B5CE2)),
              SizedBox(width: 10),
              Text('Watch Mode'),
            ],
          ),
          content: const Text(
            'WATCHKEEPER is monitoring your active departure checklist. Before leaving your Safe Zone, confirm that your important items are ready.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void showFeatureDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void showEmergencyDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Emergency Contact'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Contact name or phone number',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency contact saved'),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void showWatchDetails(Watch watch) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  watch.title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  watch.time,
                  style: const TextStyle(
                    color: Color(0xFF777B8A),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Protected items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ...watch.items.map(
                  (item) => ListTile(
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF5B5CE2),
                    ),
                    title: Text(item),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Activate Watch'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CreateWatchScreen extends StatefulWidget {
  final Function(Watch) onSave;

  const CreateWatchScreen({
    super.key,
    required this.onSave,
  });

  @override
  State<CreateWatchScreen> createState() => _CreateWatchScreenState();
}

class _CreateWatchScreenState extends State<CreateWatchScreen> {
  final titleController = TextEditingController();
  final timeController = TextEditingController();

  String category = 'WORK';
  String location = 'Home Safe Zone';

  final List<String> categories = [
    'WORK',
    'TRAVEL',
    'FAMILY',
    'EVENT',
    'SCHOOL',
    'OTHER',
  ];

  final List<String> items = [
    'Phone',
    'Keys',
    'Wallet',
    'Laptop',
  ];

  void saveWatch() {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please give your Watch a name'),
        ),
      );
      return;
    }

    widget.onSave(
      Watch(
        title: titleController.text.trim(),
        category: category,
        time: timeController.text.trim().isEmpty
            ? 'No departure time set'
            : timeController.text.trim(),
        location: location,
        items: List.from(items),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Watch',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF5B5CE2),
                  Color(0xFF7C4DFF),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 42,
                ),
                SizedBox(height: 16),
                Text(
                  'Create your protection plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tell WATCHKEEPER what you need to remember before leaving.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Watch name',
              hintText: 'Example: Airport Trip',
              prefixIcon: Icon(Icons.edit_outlined),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 18),

          DropdownButtonFormField<String>(
            value: category,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined),
              border: OutlineInputBorder(),
            ),
            items: categories
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                category = value!;
              });
            },
          ),

          const SizedBox(height: 18),

          TextField(
            controller: timeController,
            decoration: const InputDecoration(
              labelText: 'Departure time',
              hintText: 'Example: Leave at 8:00 AM',
              prefixIcon: Icon(Icons.schedule),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 18),

          DropdownButtonFormField<String>(
            value: location,
            decoration: const InputDecoration(
              labelText: 'Location trigger',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Home Safe Zone',
                child: Text('Home Safe Zone'),
              ),
              DropdownMenuItem(
                value: 'Manual reminder',
                child: Text('Manual reminder'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                location = value!;
              });
            },
          ),

          const SizedBox(height: 28),

          const Text(
            'Things to remember',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 10),

          ...items.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final item = entry.value;

              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF5B5CE2),
                  ),
                  title: Text(item),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        items.removeAt(index);
                      });
                    },
                  ),
                ),
              );
            },
          ),

          TextButton.icon(
            onPressed: () {
              final controller = TextEditingController();

              showDialog(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('Add item'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Example: Passport',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (controller.text.trim().isNotEmpty) {
                            setState(() {
                              items.add(controller.text.trim());
                            });
                          }
                          Navigator.pop(dialogContext);
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add another item'),
          ),

          const SizedBox(height: 32),

          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: saveWatch,
              icon: const Icon(Icons.shield),
              label: const Text(
                'CREATE WATCH',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B5CE2),
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
