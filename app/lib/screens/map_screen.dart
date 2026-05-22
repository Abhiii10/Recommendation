import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/maps/offline_tile_provider.dart';
import '../models/accommodation.dart';
import '../models/destination.dart';
import '../theme/app_theme.dart';
import 'details_screen.dart';

const _kCategoryIcons = <String, IconData>{
  'trekking': Icons.hiking_rounded,
  'cultural': Icons.account_balance_rounded,
  'culture': Icons.account_balance_rounded,
  'village': Icons.home_work_rounded,
  'nature': Icons.eco_rounded,
  'adventure': Icons.terrain_rounded,
  'relaxation': Icons.spa_rounded,
  'pilgrimage': Icons.temple_hindu_rounded,
  'wildlife': Icons.forest_rounded,
  'boating': Icons.sailing_rounded,
  'photography': Icons.camera_alt_rounded,
  'spiritual': Icons.brightness_5_rounded,
  'scenic': Icons.landscape_rounded,
  'historic': Icons.domain_rounded,
};

class MapScreen extends StatefulWidget {
  final List<Destination> destinations;
  final List<Accommodation> accommodations;

  const MapScreen({
    super.key,
    required this.destinations,
    required this.accommodations,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  TileProvider? _offlineTileProvider;
  bool _offlineTileLoadAttempted = false;
  Destination? _selectedDestination;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOfflineTiles());
  }

  @override
  void dispose() {
    _offlineTileProvider?.dispose();
    super.dispose();
  }

  List<Destination> get _mappedDestinations => widget.destinations
      .where((d) => d.latitude != null && d.longitude != null)
      .toList();

  LatLng get _center {
    final mapped = _mappedDestinations;
    if (mapped.isEmpty) return const LatLng(28.2096, 83.9856);

    final lat =
        mapped.fold<double>(0, (sum, d) => sum + d.latitude!) / mapped.length;
    final lng =
        mapped.fold<double>(0, (sum, d) => sum + d.longitude!) / mapped.length;

    return LatLng(lat, lng);
  }

  void _openDestination(Destination destination) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailsScreen(
          destination: destination,
          nearbyAccommodations: widget.accommodations,
        ),
      ),
    );
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  Future<void> _loadOfflineTiles() async {
    if (!supportsOfflineMbTiles) {
      setState(() => _offlineTileLoadAttempted = true);
      return;
    }

    final provider = await createOfflineTileProvider();

    if (!mounted) {
      provider?.dispose();
      return;
    }

    setState(() {
      _offlineTileProvider = provider;
      _offlineTileLoadAttempted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapped = _mappedDestinations;
    final cs = Theme.of(context).colorScheme;
    final usingOfflineTiles = _offlineTileProvider != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Destination Map'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: const Icon(Icons.place_rounded, size: 16),
              label: Text('${mapped.length} places'),
            ),
          ),
        ],
      ),
      body: mapped.isEmpty
          ? _MapEmptyState(totalDestinations: widget.destinations.length)
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 8.6,
                    minZoom: 7,
                    maxZoom: 16,
                    onTap: (_, __) =>
                        setState(() => _selectedDestination = null),
                  ),
                  children: [
                    if (usingOfflineTiles)
                      TileLayer(tileProvider: _offlineTileProvider!)
                    else
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.rural_tourism_app',
                      ),
                    MarkerLayer(
                      markers: mapped.map((destination) {
                        final point = LatLng(
                          destination.latitude!,
                          destination.longitude!,
                        );

                        return Marker(
                          point: point,
                          width: 58,
                          height: 58,
                          child: Semantics(
                            button: true,
                            label: 'Open ${destination.name} on map',
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(
                                  () => _selectedDestination = destination,
                                );
                                _mapController.move(point, 11);
                              },
                              child: _DestinationPin(
                                category: destination.category.isNotEmpty
                                    ? destination.category.first
                                    : 'scenic',
                                isSelected:
                                    _selectedDestination?.id == destination.id,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: _MapStatusChip(
                    offlineReady: usingOfflineTiles,
                    attempted: _offlineTileLoadAttempted,
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 14,
                  child: _MapControls(
                    onZoomIn: () => _zoomBy(1),
                    onZoomOut: () => _zoomBy(-1),
                    onReset: () => _mapController.move(_center, 8.6),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _selectedDestination == null
                        ? _MapHint(
                            key: const ValueKey('hint'), color: cs.primary)
                        : _DestinationPreview(
                            key: ValueKey(_selectedDestination!.id),
                            destination: _selectedDestination!,
                            onClose: () =>
                                setState(() => _selectedDestination = null),
                            onOpen: () =>
                                _openDestination(_selectedDestination!),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DestinationPin extends StatefulWidget {
  final String category;
  final bool isSelected;

  const _DestinationPin({
    required this.category,
    this.isSelected = false,
  });

  @override
  State<_DestinationPin> createState() => _DestinationPinState();
}

class _DestinationPinState extends State<_DestinationPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.categoryColour(widget.category);
    final icon =
        _kCategoryIcons[widget.category.toLowerCase()] ?? Icons.place_rounded;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Transform.scale(
        scale: widget.isSelected ? 1.0 + (_pulse.value * 0.12) : 1.0,
        child: child,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          CustomPaint(
            size: const Size(12, 7),
            painter: _PinTailPainter(color: color),
          ),
        ],
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;

  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapControlButton(icon: Icons.add_rounded, onPressed: onZoomIn),
          Divider(color: cs.outlineVariant),
          _MapControlButton(icon: Icons.remove_rounded, onPressed: onZoomOut),
          Divider(color: cs.outlineVariant),
          _MapControlButton(
              icon: Icons.my_location_rounded, onPressed: onReset),
        ],
      ),
    );
  }
}

class _MapStatusChip extends StatelessWidget {
  final bool offlineReady;
  final bool attempted;

  const _MapStatusChip({
    required this.offlineReady,
    required this.attempted,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = offlineReady ? cs.tertiary : cs.secondary;
    final label = offlineReady
        ? 'Offline map'
        : attempted
            ? 'Online map'
            : 'Preparing map';

    return Material(
      color: cs.surface.withValues(alpha: 0.94),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offlineReady ? Icons.offline_bolt_rounded : Icons.public_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Map control',
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }
}

class _DestinationPreview extends StatelessWidget {
  final Destination destination;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  const _DestinationPreview({
    super.key,
    required this.destination,
    required this.onClose,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final category =
        destination.category.isNotEmpty ? destination.category.first : 'scenic';
    final color = AppTheme.categoryColour(category);

    final location = [
      if ((destination.district ?? '').trim().isNotEmpty) destination.district!,
      if ((destination.municipality ?? '').trim().isNotEmpty)
        destination.municipality!,
    ].join(' · ');

    return Material(
      color: cs.surface,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.landscape_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    destination.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    destination.shortDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('View details'),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapHint extends StatelessWidget {
  final Color color;

  const _MapHint({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.bottomLeft,
      child: Material(
        color: cs.surface.withValues(alpha: 0.94),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                'Tap a marker',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapEmptyState extends StatelessWidget {
  final int totalDestinations;

  const _MapEmptyState({required this.totalDestinations});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.map_outlined, size: 36, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No mapped destinations yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$totalDestinations destinations loaded, but none include coordinates.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
