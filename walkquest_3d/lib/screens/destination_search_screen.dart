import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lat_lng.dart';
import '../models/route_plan.dart';
import '../services/mapbox_api_service.dart';
import '../state/settings_controller.dart';
import '../utils/formatters.dart';
import '../utils/geo_utils.dart';

/// Debounced geocoding search; pops with the chosen [PlaceResult].
class DestinationSearchScreen extends StatefulWidget {
  const DestinationSearchScreen({super.key, required this.proximity});

  final LatLng proximity;

  @override
  State<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<PlaceResult> _results = const [];
  bool _loading = false;
  String? _error;

  static const _suggestions = ['Park', 'Coffee', 'Museum', 'Beach', 'Library', 'Viewpoint'];

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<MapboxApiService>().search(q, proximity: widget.proximity);
      if (mounted && _query.text == q) setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final miles = context.watch<SettingsController>().value.useMiles;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: 'Search a destination…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)),
            )
          : _results.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final s in _suggestions)
                    ActionChip(
                      label: Text(s),
                      onPressed: () {
                        _query.text = s;
                        _search(s);
                      },
                    ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = _results[i];
                final d = GeoUtils.distanceM(widget.proximity, r.location);
                return ListTile(
                  leading: const CircleAvatar(child: Text('📍')),
                  title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: r.address == null ? null : Text(r.address!, maxLines: 2),
                  trailing: Text(Fmt.distance(d, miles: miles)),
                  onTap: () => Navigator.of(context).pop(r),
                );
              },
            ),
    );
  }
}
