import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class SceneryHero extends StatefulWidget {
  const SceneryHero({super.key});

  @override
  State<SceneryHero> createState() => _SceneryHeroState();
}

class _SceneryHeroState extends State<SceneryHero> {
  int index = 0;
  Timer? timer;

  final images = const [
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1600',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1600',
    'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=1600',
    'https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?w=1600',
    'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=1600',
  ];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() => index = (index + 1) % images.length);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: AspectRatio(
        aspectRatio: 1.35,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 1300),
              child: CachedNetworkImage(
                key: ValueKey(index),
                imageUrl: images[index],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF172554), Color(0xFF4C1D95)],
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF172554), Color(0xFF4C1D95)],
                    ),
                  ),
                  child: const Center(child: Icon(Icons.landscape, size: 48)),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDD050816)],
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Everything important is under watch.',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning ✦';
    if (hour < 17) return 'Good afternoon ✦';
    return 'Good evening ✦';
  }
}
