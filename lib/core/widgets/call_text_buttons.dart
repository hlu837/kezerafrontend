import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Call" / "Text" buttons for a candidate card, backed by the device's
/// phone/SMS apps via `tel:`/`sms:` URIs. Renders nothing when [phone]
/// is null — callers can pass `seeker.phone` straight through rather
/// than guarding with an `if` at every call site, since a null phone
/// (the general candidate-search pool, which never gets a phone number
/// attached — see utils/attachLastSeen.js#attachPhone) simply means
/// there's nothing to call.
class CallTextButtons extends StatelessWidget {
  const CallTextButtons({super.key, required this.phone});

  final String? phone;

  Future<void> _launch(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final number = phone;
    if (number == null || number.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _launch(Uri(scheme: 'tel', path: number)),
            icon: const Icon(Icons.call_outlined, size: 18),
            label: const Text('Call'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _launch(Uri(scheme: 'sms', path: number)),
            icon: const Icon(Icons.sms_outlined, size: 18),
            label: const Text('Text'),
          ),
        ),
      ],
    );
  }
}
