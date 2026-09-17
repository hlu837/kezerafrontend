import 'dart:async';

import 'package:flutter/material.dart';

import '../location/gebeta_geocoding_service.dart';

/// Opens the manual/typed-location search sheet and resolves to the
/// place the person picked, or `null` if they closed it without
/// choosing one. Shared by [NearbyExpertsMapScreen]/[NearbyAgenciesMapScreen]
/// (and their radius/filter bars' "search a place" buttons) so both
/// screens' manual fallback behaves identically — search "Bole" instead
/// of relying on device GPS.
Future<GeocodedPlace?> showPlaceSearchSheet(
  BuildContext context, {
  String title = 'Search a location',
}) {
  return showModalBottomSheet<GeocodedPlace>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PlaceSearchSheet(title: title),
  );
}

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({required this.title});

  final String title;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _service = const GebetaGeocodingService();
  final _controller = TextEditingController();
  // Debounces search-as-you-type so every keystroke doesn't fire its own
  // request — same reasoning any autocomplete field needs.
  Timer? _debounce;
  List<GeocodedPlace>? _results;
  bool _isSearching = false;
  GeocodingFailure? _failure;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = null;
        _failure = null;
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isSearching = true;
      _failure = null;
    });
    try {
      final results = await _service.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } on GeocodingException catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _failure = e.reason;
        _isSearching = false;
      });
    }
  }

  String get _failureMessage => switch (_failure) {
        GeocodingFailure.missingApiKey =>
          'Place search is not configured for this app yet.',
        GeocodingFailure.requestFailed =>
          "Couldn't search right now. Check your connection and try again.",
        GeocodingFailure.noResults =>
          'No places matched. Try a different spelling or a nearby landmark.',
        null => '',
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'e.g. Bole',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onChanged,
              onSubmitted: _search,
            ),
            const SizedBox(height: 12),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_failure != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _failureMessage,
                  style: TextStyle(color: colorScheme.error),
                ),
              )
            else if (_results != null)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results!.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = _results![index];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(place.name),
                      onTap: () => Navigator.of(context).pop(place),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
