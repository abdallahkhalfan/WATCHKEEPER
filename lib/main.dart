import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notify.instance.init();
  runApp(const WatchkeeperApp());
}

class Notify {
  Notify._();
  static final instance = Notify._();
  final plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {}
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(settings: settings);
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  NotificationDetails get details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'watchkeeper_alerts',
          'WATCHKEEPER alerts',
          channelDescription: 'Departure and preparation reminders',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        ),
      );

  Future<void> showNow(String title, String body, {int id = 9000}) => plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );

  Future<void> schedule(Watch w) async {
    await plugin.cancel(id: w.noteId);
    await plugin.cancel(id: w.noteId + 1);
    final prep = w.when.subtract(Duration(minutes: w.reminderMinutes));
    if (prep.isAfter(DateTime.now())) {
      await plugin.zonedSchedule(
        id: w.noteId,
        title: '${w.title} is coming up',
        body: 'Prepare: ${w.items.take(4).map((e) => e.name).join(', ')}',
        scheduledDate: tz.TZDateTime.from(prep, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: w.id,
      );
    }
    if (w.when.isAfter(DateTime.now())) {
      await plugin.zonedSchedule(
        id: w.noteId + 1,
        title: 'WATCHKEEPER • ${w.title}',
        body: 'Time to go. Open your checklist before leaving.',
        scheduledDate: tz.TZDateTime.from(w.when, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: w.id,
      );
    }
  }
}

class Item {
  Item(this.name, {this.done = false});
  String name;
  bool done;
  Map<String, dynamic> toJson() => {'name': name, 'done': done};
  factory Item.fromJson(Map<String, dynamic> j) => Item(j['name'], done: j['done'] ?? false);
}

class Watch {
  Watch({
    required this.id,
    required this.title,
    required this.category,
    required this.when,
    required this.items,
    this.reminderMinutes = 30,
    this.useSafeZone = true,
    this.enabled = true,
  });
  String id, title, category;
  DateTime when;
  List<Item> items;
  int reminderMinutes;
  bool useSafeZone, enabled;

  int get noteId => id.hashCode.abs() % 1000000;
  int get doneCount => items.where((e) => e.done).length;
  bool get complete => items.isNotEmpty && doneCount == items.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'when': when.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'reminderMinutes': reminderMinutes,
        'useSafeZone': useSafeZone,
        'enabled': enabled,
      };

  factory Watch.fromJson(Map<String, dynamic> j) => Watch(
        id: j['id'],
        title: j['title'],
        category: j['category'] ?? 'PERSONAL',
        when: DateTime.parse(j['when']),
        items: (j['items'] as List? ?? []).map((e) => Item.fromJson(Map<String, dynamic>.from(e))).toList(),
        reminderMinutes: j['reminderMinutes'] ?? 30,
        useSafeZone: j['useSafeZone'] ?? true,
        enabled: j['enabled'] ?? true,
      );
}

class WatchkeeperApp extends StatefulWidget {
  const WatchkeeperApp({super.key});
  @override
  State<WatchkeeperApp> createState() => _WatchkeeperAppState();
}

class _WatchkeeperAppState extends State<WatchkeeperApp> {
  ThemeMode mode = ThemeMode.system;
  Color accent = const Color(0xFF635BFF);

  void setAppearance(ThemeMode m, Color c) => setState(() {
        mode = m;
        accent = c;
      });

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'WATCHKEEPER',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: accent),
          scaffoldBackgroundColor: const Color(0xFFF4F6FB),
          cardTheme: const CardThemeData(elevation: 0),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
          scaffoldBackgroundColor: const Color(0xFF07111F),
          cardColor: const Color(0xFF101D30),
          cardTheme: const CardThemeData(elevation: 0),
        ),
        home: Shell(onAppearance: setAppearance),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.onAppearance});
  final void Function(ThemeMode, Color) onAppearance;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  bool loading = true, guardArmed = false, alertOpen = false;
  double? homeLat, homeLng;
  double radius = 40;
  int grace = 60;
  String contactName = '', contactPhone = '';
  ThemeMode mode = ThemeMode.system;
  Color accent = const Color(0xFF635BFF);
  StreamSubscription<Position>? sub;
  List<Watch> watches = [];
  List<String> activity = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('watches');
    if (raw != null) {
      try {
        watches = (jsonDecode(raw) as List).map((e) => Watch.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {}
    }
    if (watches.isEmpty) {
      watches = [
        Watch(
          id: 'starter',
          title: 'Morning Work',
          category: 'WORK',
          when: DateTime.now().add(const Duration(hours: 2)),
          items: [Item('Phone'), Item('Keys'), Item('Wallet'), Item('Water bottle'), Item('Work ID')],
        )
      ];
    }
    activity = p.getStringList('activity') ?? ['WATCHKEEPER ready'];
    homeLat = p.getDouble('homeLat');
    homeLng = p.getDouble('homeLng');
    radius = p.getDouble('radius') ?? 40;
    grace = p.getInt('grace') ?? 60;
    contactName = p.getString('contactName') ?? '';
    contactPhone = p.getString('contactPhone') ?? '';
    final savedMode = p.getString('themeMode') ?? 'system';
    mode = savedMode == 'dark' ? ThemeMode.dark : savedMode == 'light' ? ThemeMode.light : ThemeMode.system;
    accent = Color(p.getInt('accent') ?? 0xFF635BFF);
    widget.onAppearance(mode, accent);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('watches', jsonEncode(watches.map((e) => e.toJson()).toList()));
    await p.setStringList('activity', activity.take(80).toList());
    if (homeLat != null) await p.setDouble('homeLat', homeLat!);
    if (homeLng != null) await p.setDouble('homeLng', homeLng!);
    await p.setDouble('radius', radius);
    await p.setInt('grace', grace);
    await p.setString('contactName', contactName);
    await p.setString('contactPhone', contactPhone);
    await p.setString('themeMode', mode.name);
    await p.setInt('accent', accent.value);
  }

  void _log(String text) {
    setState(() => activity.insert(0, text));
    _save();
  }

  Watch? get active {
    final enabled = watches.where((w) => w.enabled).toList()..sort((a, b) => a.when.compareTo(b.when));
    return enabled.isEmpty ? null : enabled.first;
  }

  Future<bool> _locationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _snack('Turn on GPS/Location first.');
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      _snack('Location permission is required for Safe Zone.');
      return false;
    }
    return true;
  }

  Future<void> _markHome() async {
    if (!await _locationPermission()) return;
    final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    setState(() {
      homeLat = pos.latitude;
      homeLng = pos.longitude;
    });
    await _save();
    _log('Home Safe Zone saved');
    _snack('Home saved at ${radius.round()} m radius.');
  }

  Future<void> _toggleGuard() async {
    if (guardArmed) {
      await sub?.cancel();
      setState(() => guardArmed = false);
      _log('Departure Guard disarmed');
      return;
    }
    if (homeLat == null || homeLng == null) await _markHome();
    if (homeLat == null || !await _locationPermission()) return;
    setState(() => guardArmed = true);
    _log('Departure Guard armed');
    sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      final d = Geolocator.distanceBetween(homeLat!, homeLng!, pos.latitude, pos.longitude);
      final w = active;
      if (d >= radius && w != null && w.useSafeZone && !w.complete && !alertOpen) {
        _departureAlert(w, d);
      }
    });
  }

  Future<void> _departureAlert(Watch w, double distance) async {
    alertOpen = true;
    _log('Departure Guard triggered at ${distance.round()} m');
    await Notify.instance.showNow('WAIT — checklist incomplete', 'You left Home without confirming everything for ${w.title}.');
    if (!mounted) return;
    int left = grace;
    Timer? timer;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
          if (left <= 1) {
            t.cancel();
            Navigator.pop(ctx, 'timeout');
          } else {
            left--;
            setD(() {});
          }
        });
        return AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, size: 50, color: Theme.of(context).colorScheme.error),
          title: const Text('WATCHKEEPER ALERT'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('You crossed your Safe Zone with unchecked items:'),
            const SizedBox(height: 8),
            ...w.items.where((e) => !e.done).map((e) => ListTile(dense: true, leading: const Icon(Icons.radio_button_unchecked), title: Text(e.name))),
            Text('$left', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
            const Text('seconds before trusted-contact escalation'),
          ]),
          actions: [
            TextButton(onPressed: () { timer?.cancel(); Navigator.pop(ctx, 'back'); }, child: const Text('I’M GOING BACK')),
            FilledButton(onPressed: () { timer?.cancel(); Navigator.pop(ctx, 'done'); }, child: const Text('I HAVE EVERYTHING')),
          ],
        );
      }),
    );
    timer?.cancel();
    if (result == 'done') {
      for (final i in w.items) i.done = true;
      await _save();
      _log('${w.title} checklist confirmed');
    } else if (result == 'timeout') {
      await _escalate();
    }
    alertOpen = false;
  }

  Future<void> _escalate() async {
    _log('Escalation timer expired');
    await Notify.instance.showNow('WATCHKEEPER escalation', contactPhone.isEmpty ? 'No trusted contact is configured.' : 'Opening trusted contact ${contactName.isEmpty ? contactPhone : contactName}.', id: 9911);
    if (contactPhone.isEmpty) {
      _contactDialog();
      return;
    }
    final uri = Uri(scheme: 'tel', path: contactPhone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _editWatch([Watch? old]) async {
    final w = await Navigator.push<Watch>(context, MaterialPageRoute(builder: (_) => WatchEditor(initial: old)));
    if (w == null) return;
    setState(() {
      final i = old == null ? -1 : watches.indexWhere((e) => e.id == old.id);
      if (i >= 0) watches[i] = w; else watches.add(w);
    });
    await _save();
    await Notify.instance.schedule(w);
    _log(old == null ? '${w.title} created' : '${w.title} updated');
  }

  void _contactDialog() {
    final n = TextEditingController(text: contactName);
    final p = TextEditingController(text: contactPhone);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Trusted contact'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        TextField(controller: p, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', hintText: '+254...')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () { setState(() { contactName = n.text.trim(); contactPhone = p.text.trim(); }); _save(); _log('Trusted contact saved'); Navigator.pop(ctx); }, child: const Text('Save')),
      ],
    ));
  }

  void _safeZoneDialog() {
    double value = radius;
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 2, 22, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.location_on), title: Text('Home Safe Zone', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Choose how far from your doorstep WATCHKEEPER should trigger.')),
        Slider(min: 20, max: 200, divisions: 18, value: value, label: '${value.round()} m', onChanged: (v) => setS(() => value = v)),
        Text('${value.round()} meters from Home', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _markHome, icon: const Icon(Icons.my_location), label: Text(homeLat == null ? 'Mark Home' : 'Update Home'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(onPressed: () { setState(() => radius = value); _save(); Navigator.pop(ctx); }, icon: const Icon(Icons.save), label: const Text('Save'))),
        ])
      ]),
    )));
  }

  void _appearanceDialog() {
    final colors = [const Color(0xFF635BFF), const Color(0xFF007AFF), const Color(0xFF00A67E), const Color(0xFFFF7A00), const Color(0xFFE91E63), const Color(0xFF7C3AED)];
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 2, 22, 30),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Appearance', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android), label: Text('Auto')),
          ],
          selected: {mode},
          onSelectionChanged: (s) { setState(() => mode = s.first); setS(() {}); widget.onAppearance(mode, accent); _save(); },
        ),
        const SizedBox(height: 22),
        const Text('Accent color', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 12, children: colors.map((c) => InkWell(
          onTap: () { setState(() => accent = c); setS(() {}); widget.onAppearance(mode, accent); _save(); },
          child: Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: c, border: Border.all(width: 4, color: accent.value == c.value ? Theme.of(context).colorScheme.onSurface : Colors.transparent)), child: accent.value == c.value ? const Icon(Icons.check, color: Colors.white) : null),
        )).toList()),
      ]),
    )));
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = [_home(), _watchesPage(), _activityPage(), _profilePage()];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      floatingActionButton: tab < 2 ? FloatingActionButton.extended(onPressed: () => _editWatch(), icon: const Icon(Icons.add), label: const Text('New Watch')) : null,
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Watches'),
        NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: 'Activity'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ]),
    );
  }

  Widget _header(String title, String subTitle, IconData icon) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
    child: Row(children: [CircleAvatar(radius: 25, child: Icon(icon)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), Text(subTitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]))]),
  );

  Widget _home() {
    final w = active;
    return ListView(padding: const EdgeInsets.only(bottom: 110), children: [
      _header('WATCHKEEPER', 'Your personal departure buddy', Icons.shield_rounded),
      if (w != null) Padding(padding: const EdgeInsets.all(20), child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [accent, Color.lerp(accent, Colors.black, .3)!]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: accent.withValues(alpha: .25), blurRadius: 28, offset: const Offset(0, 14))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.radar, color: Colors.white), const SizedBox(width: 8), const Expanded(child: Text('WATCH MODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1))), Switch(value: guardArmed, activeThumbColor: Colors.white, onChanged: (_) => _toggleGuard())]),
          const SizedBox(height: 14), Text(w.title, style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(_format(w.when), style: const TextStyle(color: Colors.white70)), const SizedBox(height: 16), LinearProgressIndicator(value: w.items.isEmpty ? 0 : w.doneCount / w.items.length, minHeight: 9, backgroundColor: Colors.white24, color: Colors.white), const SizedBox(height: 7), Text('${w.doneCount}/${w.items.length} items confirmed', style: const TextStyle(color: Colors.white70)),
        ]),
      )),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
        Expanded(child: _quick(Icons.location_home_rounded, 'Safe Zone', homeLat == null ? 'Set Home' : '${radius.round()} m radius', _safeZoneDialog)), const SizedBox(width: 12), Expanded(child: _quick(Icons.sos_rounded, 'Trusted Contact', contactPhone.isEmpty ? 'Add contact' : (contactName.isEmpty ? contactPhone : contactName), _contactDialog)),
      ])),
      if (w != null) ...[
        const SizedBox(height: 20), Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [Expanded(child: Text('Departure checklist', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))), TextButton(onPressed: () => _editWatch(w), child: const Text('Edit'))])),
        ...w.items.map((i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), child: Card(child: CheckboxListTile(value: i.done, onChanged: (v) { setState(() => i.done = v ?? false); _save(); _log('${i.name} ${i.done ? 'confirmed' : 'unchecked'}'); }, title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)), secondary: Icon(_itemIcon(i.name), color: accent))))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child: FilledButton.icon(onPressed: () { for (final i in w.items) i.done = true; setState(() {}); _save(); _log('${w.title} completed'); }, icon: const Icon(Icons.done_all), label: const Text('Confirm everything'))),
      ],
      const SizedBox(height: 18), Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Card(child: ListTile(leading: Icon(guardArmed ? Icons.gps_fixed : Icons.gps_not_fixed, color: guardArmed ? Colors.green : null), title: Text(guardArmed ? 'Departure Guard armed' : 'Departure Guard off'), subtitle: Text(homeLat == null ? 'Set Home to activate.' : 'Triggers at ${radius.round()} m • $grace-second countdown'), trailing: Switch(value: guardArmed, onChanged: (_) => _toggleGuard())))),
    ]);
  }

  Widget _quick(IconData icon, String title, String sub, VoidCallback tap) => InkWell(onTap: tap, borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 30, color: accent), const SizedBox(height: 14), Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))])));

  Widget _watchesPage() => Column(children: [
    _header('My Watches', '${watches.length} preparation plans', Icons.shield_outlined),
    Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(20, 5, 20, 100), itemCount: watches.length, itemBuilder: (_, i) { final w = watches[i]; return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(contentPadding: const EdgeInsets.all(14), leading: CircleAvatar(radius: 25, child: Icon(_categoryIcon(w.category))), title: Text(w.title, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${_format(w.when)}\n${w.doneCount}/${w.items.length} ready • ${_lead(w.reminderMinutes)}'), isThreeLine: true, trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _editWatch(w); if (v == 'delete') { Notify.instance.plugin.cancel(id: w.noteId); Notify.instance.plugin.cancel(id: w.noteId + 1); setState(() => watches.remove(w)); _save(); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))]), onTap: () => _editWatch(w))); })),
  ]);

  Widget _activityPage() => ListView(children: [_header('Activity', 'Your preparation history', Icons.timeline), ...activity.map((a) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), child: Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.check_circle_outline)), title: Text(a), subtitle: const Text('Stored on this device')))))]);

  Widget _profilePage() => ListView(children: [
    _header('Profile & Settings', 'Make WATCHKEEPER yours', Icons.person_outline),
    _setting(Icons.location_on_outlined, 'Home Safe Zone', homeLat == null ? 'Not configured' : '${radius.round()} m radius', _safeZoneDialog),
    _setting(Icons.contacts_outlined, 'Trusted Contact', contactPhone.isEmpty ? 'Not configured' : '$contactName • $contactPhone', _contactDialog),
    _setting(Icons.timer_outlined, 'Escalation countdown', '$grace seconds', () => _countdownDialog()),
    _setting(Icons.palette_outlined, 'Appearance', '${mode.name} theme • custom accent', _appearanceDialog),
    _setting(Icons.notifications_active_outlined, 'Test notification', 'Check alerts', () => Notify.instance.showNow('WATCHKEEPER test', 'Notifications are working.')),
    _setting(Icons.security_outlined, 'Privacy', 'Data currently stays on your phone', () => _snack('WATCHKEEPER stores these settings locally on your device.')),
  ]);

  Widget _setting(IconData i, String t, String s, VoidCallback tap) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), child: Card(child: ListTile(onTap: tap, leading: CircleAvatar(child: Icon(i)), title: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(s), trailing: const Icon(Icons.chevron_right))));

  void _countdownDialog() => showDialog(context: context, builder: (ctx) => SimpleDialog(title: const Text('Escalation countdown'), children: [30, 60, 90, 120].map((s) => RadioListTile<int>(value: s, groupValue: grace, title: Text('$s seconds'), onChanged: (v) { setState(() => grace = v!); _save(); Navigator.pop(ctx); })).toList()));

  String _format(DateTime d) { final h = d.hour % 12 == 0 ? 12 : d.hour % 12; final m = d.minute.toString().padLeft(2, '0'); final a = d.hour >= 12 ? 'PM' : 'AM'; return '${d.day}/${d.month}/${d.year} • $h:$m $a'; }
  String _lead(int m) => m >= 1440 ? '${m ~/ 1440} day(s) before' : m >= 60 ? '${m ~/ 60} hr before' : '$m min before';
  IconData _categoryIcon(String c) => c == 'WORK' ? Icons.business_center_outlined : c == 'TRAVEL' ? Icons.flight_takeoff : c == 'EVENT' ? Icons.celebration_outlined : c == 'FAMILY' ? Icons.family_restroom : c == 'SHOPPING' ? Icons.shopping_cart_outlined : Icons.shield_outlined;
  IconData _itemIcon(String s) { final x = s.toLowerCase(); if (x.contains('phone')) return Icons.phone_android; if (x.contains('key')) return Icons.key; if (x.contains('wallet')) return Icons.account_balance_wallet_outlined; if (x.contains('water')) return Icons.water_drop_outlined; if (x.contains('passport') || x.contains('id')) return Icons.badge_outlined; if (x.contains('laptop')) return Icons.laptop; if (x.contains('gift')) return Icons.card_giftcard; return Icons.inventory_2_outlined; }
}

class WatchEditor extends StatefulWidget {
  const WatchEditor({super.key, this.initial});
  final Watch? initial;
  @override
  State<WatchEditor> createState() => _WatchEditorState();
}

class _WatchEditorState extends State<WatchEditor> {
  late TextEditingController title;
  late String category;
  late DateTime when;
  late int reminder;
  late bool safeZone;
  late List<Item> items;
  final categories = ['WORK', 'TRAVEL', 'EVENT', 'FAMILY', 'SHOPPING', 'PERSONAL'];
  final leads = [10, 30, 60, 180, 1440, 2880];

  @override
  void initState() {
    super.initState();
    final w = widget.initial;
    title = TextEditingController(text: w?.title ?? '');
    category = w?.category ?? 'PERSONAL';
    when = w?.when ?? DateTime.now().add(const Duration(hours: 1));
    reminder = w?.reminderMinutes ?? 30;
    safeZone = w?.useSafeZone ?? true;
    items = (w?.items ?? [Item('Phone'), Item('Keys'), Item('Wallet')]).map((e) => Item(e.name, done: e.done)).toList();
  }

  void _addItem() {
    final c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Add essential item'), content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Water bottle')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { if (c.text.trim().isNotEmpty) setState(() => items.add(Item(c.text.trim()))); Navigator.pop(ctx); }, child: const Text('Add'))]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.initial == null ? 'New Watch' : 'Edit Watch')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      TextField(controller: title, decoration: const InputDecoration(labelText: 'Watch title', hintText: 'Wedding, Work, Baby shower...', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit_outlined))),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)), items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => category = v!)),
      const SizedBox(height: 10),
      Card(child: ListTile(leading: const Icon(Icons.event), title: const Text('Date and time'), subtitle: Text(_date(when)), trailing: const Icon(Icons.edit_calendar), onTap: () async { final d = await showDatePicker(context: context, initialDate: when, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650))); if (d == null || !mounted) return; final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(when)); if (t != null) setState(() => when = DateTime(d.year, d.month, d.day, t.hour, t.minute)); })),
      const SizedBox(height: 10),
      DropdownButtonFormField<int>(initialValue: reminder, decoration: const InputDecoration(labelText: 'Prepare reminder', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notifications_outlined)), items: leads.map((m) => DropdownMenuItem(value: m, child: Text(_lead(m)))).toList(), onChanged: (v) => setState(() => reminder = v!)),
      SwitchListTile(value: safeZone, onChanged: (v) => setState(() => safeZone = v), title: const Text('Use Home Departure Guard'), subtitle: const Text('Trigger checklist after crossing the Safe Zone.')),
      Row(children: [Expanded(child: Text('Essential checklist', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))), TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Add'))]),
      ...items.asMap().entries.map((e) => Card(child: ListTile(title: Text(e.value.name), leading: const Icon(Icons.drag_indicator), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => items.removeAt(e.key)))))),
      const SizedBox(height: 18),
      FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)), onPressed: () { if (title.text.trim().isEmpty) return; Navigator.pop(context, Watch(id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(), title: title.text.trim(), category: category, when: when, items: items, reminderMinutes: reminder, useSafeZone: safeZone, enabled: widget.initial?.enabled ?? true)); }, icon: const Icon(Icons.shield), label: Text(widget.initial == null ? 'CREATE WATCH' : 'SAVE WATCH')),
    ]),
  );

  String _date(DateTime d) { final h = d.hour % 12 == 0 ? 12 : d.hour % 12; final m = d.minute.toString().padLeft(2, '0'); return '${d.day}/${d.month}/${d.year} • $h:$m ${d.hour >= 12 ? 'PM' : 'AM'}'; }
  String _lead(int m) => m == 2880 ? '2 days before' : m == 1440 ? '1 day before' : m >= 60 ? '${m ~/ 60} hours before' : '$m minutes before';
}
