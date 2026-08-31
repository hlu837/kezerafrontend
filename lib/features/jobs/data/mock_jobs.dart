import '../domain/job.dart';

/// Placeholder listings shown when the real `/jobs` board comes back
/// empty — lets anyone previewing the app see what a populated job board
/// looks like before real employers/agencies have posted anything.
///
/// `JobsRepository.browseJobs` swaps these in only when the live result
/// is empty; the moment a real job exists, the real data takes over and
/// this is never touched. See `JobBrowseResult.isMock`, which the UI uses
/// to show a "sample listings" banner so nobody mistakes these for real
/// postings.
class MockJobs {
  const MockJobs._();

  static final List<Job> items = [
    Job(
      id: 'mock-1',
      creatorId: 'mock-employer-1',
      creatorType: 'employer',
      title: 'Frontend Developer (Flutter)',
      description:
          'Join our product team building the KezearaJobs mobile app. '
          'You will work closely with designers and backend engineers to '
          'ship new features every sprint.',
      location: 'Addis Ababa, Bole',
      salaryRange: '25,000 - 40,000 ETB',
      jobType: JobType.fullTime,
      category: 'tech_software',
      skillsRequired: const ['Flutter', 'Dart', 'REST APIs'],
      status: JobStatus.open,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Job(
      id: 'mock-2',
      creatorId: 'mock-employer-2',
      creatorType: 'employer',
      title: 'Front Desk Receptionist',
      description:
          'Busy hotel in Bole is looking for a friendly, well-organized '
          'receptionist to manage guest check-in/out and phone inquiries.',
      location: 'Addis Ababa, Bole',
      salaryRange: '8,000 - 12,000 ETB',
      jobType: JobType.fullTime,
      category: 'hospitality_hotel',
      skillsRequired: const ['Customer Service', 'English', 'Amharic'],
      status: JobStatus.open,
      createdAt: DateTime.now().subtract(const Duration(hours: 9)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 9)),
    ),
    Job(
      id: 'mock-3',
      creatorId: 'mock-agency-1',
      creatorType: 'agency',
      title: 'Construction Laborers Needed (10 positions)',
      description:
          'Staffing agency hiring general laborers for an active '
          'construction site. Daily pay, transport provided.',
      location: 'Adama',
      salaryRange: '400 - 600 ETB/day',
      jobType: JobType.daily,
      category: 'construction_labor',
      skillsRequired: const ['Physical Stamina', 'Teamwork'],
      status: JobStatus.open,
      createdAt: DateTime.now().subtract(const Duration(hours: 20)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 20)),
    ),
    Job(
      id: 'mock-4',
      creatorId: 'mock-employer-3',
      creatorType: 'employer',
      title: 'Delivery Motorbike Rider',
      description:
          'Food delivery startup looking for reliable riders with their '
          'own motorbike to cover the Bole and CMC areas.',
      location: 'Addis Ababa, CMC',
      salaryRange: '10,000 - 15,000 ETB',
      jobType: JobType.contract,
      category: 'driver_delivery',
      skillsRequired: const ['Motorbike License', 'Navigation'],
      status: JobStatus.open,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
    ),
    Job(
      id: 'mock-5',
      creatorId: 'mock-employer-4',
      creatorType: 'employer',
      title: 'Sales & Marketing Associate',
      description:
          'Growing retail brand seeking an energetic sales associate to '
          'drive in-store promotions and manage social media campaigns.',
      location: 'Hawassa',
      salaryRange: '9,000 - 14,000 ETB',
      jobType: JobType.fullTime,
      category: 'sales_marketing',
      skillsRequired: const ['Sales', 'Social Media', 'Communication'],
      status: JobStatus.open,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 15)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1, hours: 15)),
    ),
    Job(
      id: 'mock-6',
      creatorId: 'mock-employer-5',
      creatorType: 'employer',
      title: 'Nurse (Outpatient Clinic)',
      description:
          'Private clinic seeking a licensed nurse for outpatient care, '
          'vitals monitoring, and patient support during weekday shifts.',
      location: 'Addis Ababa, Kazanchis',
      salaryRange: '15,000 - 22,000 ETB',
      jobType: JobType.fullTime,
      category: 'healthcare',
      skillsRequired: const ['Nursing License', 'Patient Care'],
      status: JobStatus.open,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  /// Filters the mock set the same way the backend would filter real
  /// jobs, so typing into the search filters still feels functional
  /// during a preview instead of always showing the full fixed list.
  static List<Job> filtered(JobBrowseParams params) {
    return items.where((job) {
      if (params.keyword != null && params.keyword!.trim().isNotEmpty) {
        final keyword = params.keyword!.trim().toLowerCase();
        final matchesKeyword = job.title.toLowerCase().contains(keyword) ||
            job.description.toLowerCase().contains(keyword);
        if (!matchesKeyword) return false;
      }
      if (params.location != null && params.location!.trim().isNotEmpty) {
        final location = params.location!.trim().toLowerCase();
        if (!job.location.toLowerCase().contains(location)) return false;
      }
      if (params.jobType != null && job.jobType != params.jobType) {
        return false;
      }
      if (params.category != null &&
          params.category!.isNotEmpty &&
          job.category != params.category) {
        return false;
      }
      if (params.skills.isNotEmpty) {
        final jobSkillsLower = job.skillsRequired.map((s) => s.toLowerCase());
        final matchesAllSkills = params.skills.every(
          (skill) => jobSkillsLower.any((s) => s.contains(skill.toLowerCase())),
        );
        if (!matchesAllSkills) return false;
      }
      return true;
    }).toList();
  }
}
