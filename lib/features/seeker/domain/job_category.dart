import 'package:flutter/material.dart';

/// Mirrors the backend's `JOB_CATEGORY_KEYS`
/// (`backend/src/utils/jobCategories.taxonomy.js`). Closed set shown as
/// the selectable cards on the SEEK-01 Category & Preference Setup
/// screen — keep this list's `key`s in sync with the backend's, since
/// `PATCH /seekers/me/preferences` rejects anything outside that enum.
class JobCategory {
  const JobCategory({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const List<JobCategory> kJobCategories = [
  JobCategory(
    key: 'tech_software',
    label: 'Tech & Software',
    icon: Icons.laptop_mac_outlined,
  ),
  JobCategory(
    key: 'hospitality_hotel',
    label: 'Hospitality & Hotel',
    icon: Icons.hotel_outlined,
  ),
  JobCategory(
    key: 'construction_labor',
    label: 'Construction & Daily Labor',
    icon: Icons.construction_outlined,
  ),
  JobCategory(
    key: 'driver_delivery',
    label: 'Driver & Delivery',
    icon: Icons.local_shipping_outlined,
  ),
  JobCategory(
    key: 'sales_marketing',
    label: 'Sales & Marketing',
    icon: Icons.campaign_outlined,
  ),
  JobCategory(
    key: 'healthcare',
    label: 'Healthcare',
    icon: Icons.medical_services_outlined,
  ),
  JobCategory(
    key: 'other',
    label: 'Other Categories',
    icon: Icons.apps_outlined,
  ),
];
