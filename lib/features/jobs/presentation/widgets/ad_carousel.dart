import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// One ad slot. Swap [MockAds.items] for a real feed once there's a
/// backend endpoint for sponsored/featured content — this widget doesn't
/// care where the data comes from.
class AdCardData {
  const AdCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color foreground;
}

/// Placeholder ad content until real sponsored listings exist.
class MockAds {
  const MockAds._();

  static const items = [
    AdCardData(
      title: 'Go Premium',
      subtitle: 'Unlock unlimited applications and priority support.',
      icon: Icons.workspace_premium_rounded,
      background: AppColors.green,
      foreground: Colors.white,
    ),
    AdCardData(
      title: 'Hiring? Post a job in minutes',
      subtitle: 'Reach thousands of job seekers across Ethiopia today.',
      icon: Icons.campaign_rounded,
      background: Color(0xFF1A3A5C),
      foreground: Colors.white,
    ),
    AdCardData(
      title: 'Work with trusted agencies',
      subtitle: 'Verified staffing agencies ready to place you fast.',
      icon: Icons.verified_rounded,
      background: Color(0xFF6B4EA6),
      foreground: Colors.white,
    ),
    AdCardData(
      title: 'Refer a friend, earn rewards',
      subtitle: 'Invite friends and get rewarded when they get hired.',
      icon: Icons.card_giftcard_rounded,
      background: Color(0xFFB07A1E),
      foreground: Colors.white,
    ),
  ];
}

/// Small, self-advancing horizontal ad carousel for the landing page header.
///
/// Replaces the old static "Find your next job in Ethiopia" hero block —
/// this is meant to read as an ad slot, not page copy, so it's shorter and
/// slides to the next card every [interval] on its own. Swipeable by hand
/// too; user interaction just resets the auto-advance clock.
class AdCarousel extends StatefulWidget {
  const AdCarousel({
    super.key,
    this.ads = MockAds.items,
    this.interval = const Duration(seconds: 2),
    this.height = 132,
  });

  final List<AdCardData> ads;
  final Duration interval;
  final double height;

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.ads.length < 2) return;
    _timer = Timer.periodic(widget.interval, (_) => _advance());
  }

  void _advance() {
    if (!_controller.hasClients) return;
    final next = (_page + 1) % widget.ads.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.ads.length,
            onPageChanged: (index) {
              setState(() => _page = index);
              // Restart the clock so a manual swipe doesn't get immediately
              // overridden by a queued auto-advance.
              _startTimer();
            },
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _AdCard(data: widget.ads[index]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.ads.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.green : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({required this.data});

  final AdCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(data.icon, color: data.foreground, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: data.foreground,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: data.foreground.withOpacity(0.9),
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
