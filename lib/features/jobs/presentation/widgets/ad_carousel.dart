import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/auth_provider.dart';

/// One ad slot, whether it came from the real `/ads/active` feed or
/// [MockAds] fallback content — this widget doesn't care which.
class AdCardData {
  const AdCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.foreground,
    this.linkUrl,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color foreground;
  final String? linkUrl;
}

/// Placeholder ad content shown only when the real feed has nothing to
/// show yet (no employer has an active ad), or the request fails —
/// keeps the landing page from showing an empty carousel.
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

/// Maps the backend's fixed `icon` enum (see Ad.model.js#AD_ICONS) to a
/// glyph. Kept as an explicit switch (not a lookup map keyed by
/// arbitrary strings) so an unrecognized/future value falls back to
/// something sensible instead of crashing.
IconData _iconFor(String? name) {
  switch (name) {
    case 'workspace_premium':
      return Icons.workspace_premium_rounded;
    case 'verified':
      return Icons.verified_rounded;
    case 'card_giftcard':
      return Icons.card_giftcard_rounded;
    case 'storefront':
      return Icons.storefront_rounded;
    case 'local_offer':
      return Icons.local_offer_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'business_center':
      return Icons.business_center_rounded;
    case 'campaign':
    default:
      return Icons.campaign_rounded;
  }
}

// A rotating set of background colors for real employer/agency ads,
// since the backend doesn't (and shouldn't need to) let advertisers
// pick an arbitrary brand color per ad.
const _liveAdBackgrounds = [
  Color(0xFF1A3A5C),
  Color(0xFF6B4EA6),
  Color(0xFFB07A1E),
  AppColors.green,
];

/// GET /ads/active — the real, paid+admin-approved sponsored content
/// feed. Public endpoint, no auth required, so this loads for guests
/// on the public job board too.
final activeAdsProvider = FutureProvider<List<AdCardData>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response =
      await client.dio.get<Map<String, dynamic>>('/ads/active');
  final data = response.data!['data'] as Map<String, dynamic>;
  final ads = List<Map<String, dynamic>>.from(data['ads'] as List<dynamic>);

  return [
    for (var i = 0; i < ads.length; i++)
      AdCardData(
        title: ads[i]['title'] as String? ?? '',
        subtitle: ads[i]['subtitle'] as String? ?? '',
        icon: _iconFor(ads[i]['icon'] as String?),
        background: _liveAdBackgrounds[i % _liveAdBackgrounds.length],
        foreground: Colors.white,
        linkUrl: ads[i]['linkUrl'] as String?,
      ),
  ];
});

/// Small, self-advancing horizontal ad carousel for the landing page header.
///
/// Loads real sponsored content from [activeAdsProvider] and falls back
/// to [MockAds] while loading, on error, or when there simply aren't
/// any active (paid + admin-approved) ads right now — so the carousel
/// is never empty, but also never fakes engagement on a real ad.
class AdCarousel extends ConsumerStatefulWidget {
  const AdCarousel({
    super.key,
    this.interval = const Duration(seconds: 2),
    this.height = 132,
  });

  final Duration interval;
  final double height;

  @override
  ConsumerState<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends ConsumerState<AdCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;
  List<AdCardData> _ads = const [];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_ads.length < 2) return;
    _timer = Timer.periodic(widget.interval, (_) => _advance());
  }

  void _advance() {
    if (!_controller.hasClients) return;
    final next = (_page + 1) % _ads.length;
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
    final asyncAds = ref.watch(activeAdsProvider);
    // Real ads when there are any; MockAds fallback otherwise (still
    // loading, request failed, or the feed is genuinely empty).
    final ads = asyncAds.when(
      data: (real) => real.isEmpty ? MockAds.items : real,
      loading: () => MockAds.items,
      error: (_, __) => MockAds.items,
    );

    if (!_adListsEqual(ads, _ads)) {
      _ads = ads;
      // Restart the auto-advance clock against the new list length,
      // and clamp the current page if the new list is shorter.
      if (_page >= _ads.length) _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer());
    }

    if (ads.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: ads.length,
            onPageChanged: (index) {
              setState(() => _page = index);
              // Restart the clock so a manual swipe doesn't get immediately
              // overridden by a queued auto-advance.
              _startTimer();
            },
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _AdCard(data: ads[index]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < ads.length; i++)
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

/// Shallow equality check for the small ad lists this widget deals
/// with — avoids restarting the auto-advance timer/rebuilding on every
/// provider notification when the content hasn't actually changed.
/// Named distinctly from foundation's `listEquals` (pulled in
/// transitively via material.dart) to avoid a collision.
bool _adListsEqual(List<AdCardData> a, List<AdCardData> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].title != b[i].title || a[i].subtitle != b[i].subtitle) return false;
  }
  return true;
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

