import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/services.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.onMode, required this.onSeed});

  final ValueChanged<ThemeMode> onMode;
  final ValueChanged<Color> onSeed;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String home = 'Not marked';
  String contact = 'Not configured';

  Future<void> mark() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('homeLat', position.latitude);
    await prefs.setDouble('homeLng', position.longitude);
    if (mounted) {
      setState(() => home = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
    }
  }

  Future<void> trusted() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trusted contact'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number'),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('trusted', controller.text.trim());
              if (mounted) setState(() => contact = controller.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final accents = <Color>[
      const Color(0xFF7C5CFF),
      const Color(0xFF00A8E8),
      const Color(0xFF00A86B),
      const Color(0xFFFF6A2A),
      const Color(0xFFE63E8C),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      children: [
        const Text('Profile & Studio', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 30)),
            title: Text(
              user.displayName ?? 'WATCHKEEPER user',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            subtitle: Text(user.email ?? ''),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.home_work_outlined),
                title: const Text('Mark Home safe zone'),
                subtitle: Text(home),
                onTap: mark,
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('Trusted contact'),
                subtitle: Text(contact),
                onTap: trusted,
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Test notification'),
                onTap: Alerts.i.test,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appearance', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  children: [
                    ActionChip(label: const Text('Auto'), onPressed: () => widget.onMode(ThemeMode.system)),
                    ActionChip(label: const Text('Light'), onPressed: () => widget.onMode(ThemeMode.light)),
                    ActionChip(label: const Text('Midnight'), onPressed: () => widget.onMode(ThemeMode.dark)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: accents
                      .map(
                        (color) => InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => widget.onSeed(color),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: color.withValues(alpha: .35), blurRadius: 14),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => FirebaseAuth.instance.signOut(),
          ),
        ),
      ],
    );
  }
}
