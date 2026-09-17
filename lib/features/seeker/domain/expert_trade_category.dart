import 'package:flutter/material.dart';

/// Mirrors the backend's `EXPERT_TRADE_CATEGORY_KEYS`
/// (`backend/src/utils/expertTradeCategories.taxonomy.js`). Individual
/// skilled-trade categories for the "Experts" directory (electricians,
/// plumbers, ...) — deliberately separate from [JobCategory]
/// (job_category.dart), which is the broad bucket set standard job
/// postings/seekers use. Keep this list's `key`s in sync with the
/// backend's, since `GET /seekers/nearby`'s `trade` filter and
/// `PATCH /seekers/me`'s `trade_category` field reject anything
/// outside that enum.
class ExpertTradeCategory {
  const ExpertTradeCategory({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const List<ExpertTradeCategory> kExpertTradeCategories = [
  ExpertTradeCategory(
    key: 'electrician',
    label: 'Electricians',
    icon: Icons.bolt_outlined,
  ),
  ExpertTradeCategory(
    key: 'plumber',
    label: 'Plumbers',
    icon: Icons.plumbing_outlined,
  ),
  ExpertTradeCategory(
    key: 'carpenter',
    label: 'Carpenters',
    icon: Icons.carpenter_outlined,
  ),
  ExpertTradeCategory(
    key: 'mason',
    label: 'Masons',
    icon: Icons.foundation_outlined,
  ),
  ExpertTradeCategory(
    key: 'painter',
    label: 'Painters',
    icon: Icons.format_paint_outlined,
  ),
  ExpertTradeCategory(
    key: 'mechanic',
    label: 'Mechanics',
    icon: Icons.build_outlined,
  ),
  ExpertTradeCategory(
    key: 'welder',
    label: 'Welders',
    icon: Icons.whatshot_outlined,
  ),
  ExpertTradeCategory(
    key: 'tailor',
    label: 'Tailors',
    icon: Icons.content_cut_outlined,
  ),
  ExpertTradeCategory(
    key: 'hairdresser_beautician',
    label: 'Hairdressers & Beauticians',
    icon: Icons.face_retouching_natural_outlined,
  ),
  ExpertTradeCategory(
    key: 'gardener_landscaper',
    label: 'Gardeners & Landscapers',
    icon: Icons.yard_outlined,
  ),
  ExpertTradeCategory(
    key: 'appliance_repair',
    label: 'Appliance Repair Techs',
    icon: Icons.handyman_outlined,
  ),
  ExpertTradeCategory(
    key: 'cleaner',
    label: 'Cleaners',
    icon: Icons.cleaning_services_outlined,
  ),
  ExpertTradeCategory(
    key: 'other_trade',
    label: 'Other Trades',
    icon: Icons.apps_outlined,
  ),
];

/// Looks up a trade's display metadata (label/icon) by its key — used
/// wherever only the key is on hand (e.g. a [NearbySeeker]'s
/// `tradeCategory` field) but the full card needs a label/icon too.
ExpertTradeCategory? expertTradeCategoryByKey(String? key) {
  if (key == null) return null;
  for (final category in kExpertTradeCategories) {
    if (category.key == key) return category;
  }
  return null;
}
