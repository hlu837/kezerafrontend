import 'package:flutter/material.dart';

/// Globe-icon language picker shown in the seeker/employer dashboard app
/// bars (`seekerHeaderActions`/`employerHeaderActions`) and on the public
/// landing page's app bar (`PublicJobBoardScreen`) — one shared widget so
/// the three surfaces can't drift the way three separately-maintained
/// copies eventually would.
///
/// The app has no actual i18n/localization pipeline wired up yet (no ARB
/// files, no `flutter_localizations` delegate) — this is deliberately a
/// stub that lets someone see the switcher and pick a language now,
/// while the real string-translation work lands separately. Selecting a
/// language currently just confirms the tap with a "coming soon"
/// snackbar rather than silently doing nothing.
class LanguageSwitcherButton extends StatelessWidget {
  const LanguageSwitcherButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language_outlined),
      tooltip: 'Language',
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'am', child: Text('አማርኛ (Amharic)')),
      ],
      onSelected: (value) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('More languages are coming soon.')),
      ),
    );
  }
}
