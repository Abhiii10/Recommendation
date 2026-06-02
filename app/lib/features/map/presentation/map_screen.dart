import 'dart:async';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rural_tourism_app/core/maps/offline_tile_provider.dart';
import 'package:rural_tourism_app/core/navigation/location_service.dart';
import 'package:rural_tourism_app/core/navigation/models/route_result.dart';
import 'package:rural_tourism_app/core/navigation/routing_service.dart';
import 'package:rural_tourism_app/features/map/presentation/widgets/navigation_overlay.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/shared/theme/app_theme.dart';
import 'package:rural_tourism_app/features/destinations/domain/services/accommodation_matcher.dart';
import 'package:rural_tourism_app/features/destinations/presentation/details_screen.dart';

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
  final VoidCallback? onOpenAbout;

  const MapScreen({
    super.key,
    required this.destinations,
    required this.accommodations,
    this.onOpenAbout,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, ({String url, String name, bool dark})> _tileStyles =
      {
    'voyager': (
      url:
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
      name: '🗺 Voyager',
      dark: false,
    ),
    'positron': (
      url: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
      name: '⬜ Light',
      dark: false,
    ),
    'dark_matter': (
      url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
      name: '⬛ Dark',
      dark: true,
    ),
    'osm': (
      url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      name: '🌍 Standard',
      dark: false,
    ),
  };

  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();
  final LocationService _locationService = const LocationService();
  TileProvider? _offlineTileProvider;
  late final AnimationController _locationPulseController;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _offlineTileLoadAttempted = false;
  bool _offlineTilesUnavailableNoticeShown = false;
  bool _routeLoading = false;
  bool _navigationActive = false;
  bool _isOnline = true;
  Destination? _selectedDestination;
  Destination? _routeDestination;
  RouteResult? _activeRoute;
  LatLng? _routeOrigin;
  LatLng? _currentLocation;
  TravelMode _travelMode = TravelMode.driving;
  int _currentStepIndex = 0;
  String? _routeError;
  String _tileStyle = 'voyager';

  @override
  void initState() {
    super.initState();
    _locationPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    unawaited(_loadOfflineTiles());
    unawaited(_loadTileStyle());
    unawaited(_loadConnectivityStatus());
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          _updateConnectivity,
        );
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    unawaited(_connectivitySubscription?.cancel());
    _locationPulseController.dispose();
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

  LatLng? _destinationPoint(Destination destination) {
    final lat = destination.latitude;
    final lng = destination.longitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  RouteResult? _routeFor(Destination destination) {
    if (_routeDestination?.id != destination.id) return null;
    return _activeRoute;
  }

  Future<void> _loadConnectivityStatus() async {
    try {
      _updateConnectivity(await Connectivity().checkConnectivity());
    } catch (_) {
      _updateConnectivity(const [ConnectivityResult.none]);
    }
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    if (!mounted || _isOnline == isOnline) return;
    setState(() => _isOnline = isOnline);
  }

  void _handleDestinationTap(Destination destination, LatLng point) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDestination = destination;
      if (_routeDestination?.id != destination.id) {
        _travelMode = TravelMode.driving;
        _activeRoute = null;
        _routeDestination = null;
        _routeOrigin = null;
        _currentStepIndex = 0;
        _routeError = null;
      }
    });
    _mapController.move(
        point, _navigationActive ? _mapController.camera.zoom : 11);

    if (!_navigationActive) {
      unawaited(_showRouteBottomSheet(destination));
    }
  }

  Future<void> _showRouteBottomSheet(Destination destination) async {
    var didRequestInitialRoute = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> refreshAfter(Future<void> Function() action) async {
              final future = action();
              setSheetState(() {});
              await future;
              if (sheetContext.mounted) setSheetState(() {});
            }

            if (!didRequestInitialRoute &&
                _routeFor(destination) == null &&
                !_routeLoading) {
              didRequestInitialRoute = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!sheetContext.mounted) return;
                unawaited(
                  refreshAfter(
                    () async {
                      await _loadRoute(destination, _travelMode);
                    },
                  ),
                );
              });
            }

            return _RouteActionSheet(
              destination: destination,
              route: _routeFor(destination),
              selectedMode: _travelMode,
              isLoading: _routeLoading,
              errorText: _visibleRouteErrorText,
              onModeChanged: (mode) => refreshAfter(
                () async {
                  await _loadRoute(destination, mode);
                },
              ),
              onGetDirections: () => refreshAfter(
                () async {
                  final route = await _loadRoute(destination, _travelMode);
                  if (route != null && sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                },
              ),
              onStartNavigation: () => refreshAfter(
                () async {
                  final started =
                      await _startNavigation(destination, _travelMode);
                  if (started && sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                },
              ),
              onOpenDetails: () {
                Navigator.pop(sheetContext);
                _openDestination(destination);
              },
            );
          },
        );
      },
    );
  }

  Future<RouteResult?> _loadRoute(
    Destination destination,
    TravelMode mode,
  ) async {
    final destinationPoint = _destinationPoint(destination);
    if (destinationPoint == null) return null;

    if (_routeDestination?.id == destination.id &&
        _activeRoute?.travelMode == mode &&
        _activeRoute != null) {
      return _activeRoute;
    }

    setState(() {
      _travelMode = mode;
      _routeDestination = destination;
      _routeLoading = true;
      _routeError = null;
    });

    final position = _currentLocation == null
        ? await _locationService.currentPosition(context)
        : null;
    if (!mounted) return null;

    final origin = _currentLocation ??
        (position == null
            ? null
            : LatLng(position.latitude, position.longitude));

    if (origin == null) {
      setState(() {
        _routeLoading = false;
        _routeError = 'Location permission needed for navigation';
      });
      return null;
    }

    final route = await _routingService.getRoute(
      origin,
      destinationPoint,
      travelMode: mode,
    );
    if (!mounted) return null;

    setState(() {
      _currentLocation = origin;
      _routeOrigin = origin;
      _activeRoute = route;
      _routeDestination = destination;
      _routeLoading = false;
      _currentStepIndex = 0;
      _routeError = route == null
          ? (_isOnline
              ? 'Could not build a route. Try another travel mode.'
              : 'Offline - showing approximate route')
          : null;
    });

    if (route != null) _focusRoute(route.polylinePoints);
    return route;
  }

  String? get _visibleRouteErrorText {
    if (_routeError == null) return null;
    if (!_isOnline) return 'Offline - showing approximate route';
    return _routeError;
  }

  void _focusRoute(List<LatLng> points) {
    if (points.length < 2) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(44, 86, 44, 210),
      ),
    );
  }

  Future<bool> _startNavigation(
    Destination destination,
    TravelMode mode,
  ) async {
    final route = await _loadRoute(destination, mode);
    if (route == null || !mounted) return false;

    final stream = await _locationService.positionStream(context);
    if (stream == null || !mounted) return false;

    await _positionSubscription?.cancel();
    setState(() {
      _navigationActive = true;
      _currentStepIndex = 0;
      _routeDestination = destination;
    });

    _positionSubscription = stream.listen(
      _handlePositionUpdate,
      onError: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updates stopped.')),
        );
      },
    );

    final location = _currentLocation;
    if (location != null) _recenterOn(location);
    return true;
  }

  void _handlePositionUpdate(Position position) {
    if (!mounted || _activeRoute == null) return;

    final location = LatLng(position.latitude, position.longitude);

    setState(() {
      _currentLocation = location;
    });

    _recenterOn(location, heading: position.heading);
  }

  void _recenterOn(LatLng location, {double? heading}) {
    final zoom =
        _mapController.camera.zoom < 15 ? 15.0 : _mapController.camera.zoom;
    if (heading != null && heading.isFinite && heading >= 0) {
      _mapController.moveAndRotate(location, zoom, heading);
      return;
    }
    _mapController.move(location, zoom);
  }

  Future<void> _endNavigation() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (!mounted) return;
    setState(() {
      _navigationActive = false;
      _currentStepIndex = 0;
    });
  }

  void _openDestination(Destination destination) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailsScreen(
          destination: destination,
          nearbyAccommodations:
              accommodationsForDestination(destination, widget.accommodations),
        ),
      ),
    );
  }

  Future<void> _openExternalMap(Destination destination) async {
    final lat = destination.latitude;
    final lng = destination.longitude;

    if (lat == null || lng == null) return;

    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': '$lat,$lng',
      },
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps.')),
      );
    }
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

    if (provider == null && !_offlineTilesUnavailableNoticeShown) {
      _offlineTilesUnavailableNoticeShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline maps unavailable — using online tiles'),
        ),
      );
    }
  }

  Future<void> _loadTileStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('map_tile_provider') ?? 'voyager';
    if (!mounted || !_tileStyles.containsKey(saved)) return;
    setState(() => _tileStyle = saved);
  }

  Future<void> _selectTileStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_tile_provider', style);
    if (!mounted) return;
    setState(() => _tileStyle = style);
  }

  Future<void> _showTileStyleSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            children: [
              Text(
                'Map Style',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              ..._tileStyles.entries.map((entry) {
                final selected = entry.key == _tileStyle;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value.name),
                  trailing: selected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: Theme.of(sheetContext).colorScheme.primary,
                        )
                      : null,
                  onTap: () async {
                    await _selectTileStyle(entry.key);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapped = _mappedDestinations;
    final cs = Theme.of(context).colorScheme;
    final offlineTilesReady = _offlineTileProvider != null;
    final usingOfflineTiles = !_isOnline && offlineTilesReady;
    final tileStyle = _tileStyles[_tileStyle] ?? _tileStyles['voyager']!;
    final activeTileIsDark = !usingOfflineTiles && tileStyle.dark;
    final pinBorderColor = activeTileIsDark
        ? Colors.white
        : cs.surface.withValues(alpha: 0.95);

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
          if (widget.onOpenAbout != null)
            IconButton(
              tooltip: 'About',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: widget.onOpenAbout,
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
                      TileLayer(
                        tileProvider: _offlineTileProvider!,
                        maxNativeZoom: 14,
                        tileDimension: 256,
                        keepBuffer: 5,
                      )
                    else
                      TileLayer(
                        urlTemplate: tileStyle.url,
                        fallbackUrl:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: _tileStyle == 'osm'
                            ? const []
                            : const ['a', 'b', 'c', 'd'],
                        tileProvider: CancellableNetworkTileProvider(
                          silenceExceptions: true,
                        ),
                        userAgentPackageName: 'com.example.rural_tourism_app',
                      ),
                    if (_activeRoute != null &&
                        _activeRoute!.polylinePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _activeRoute!.polylinePoints,
                            color: cs.primary.withValues(alpha: 0.85),
                            strokeWidth: 6,
                            borderColor: Colors.white,
                            borderStrokeWidth: 9,
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        ...mapped.map((destination) {
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
                                onTap: () =>
                                    _handleDestinationTap(destination, point),
                                child: _DestinationPin(
                                  category: destination.category.isNotEmpty
                                      ? destination.category.first
                                      : 'scenic',
                                  isSelected: _selectedDestination?.id ==
                                      destination.id,
                                  borderColor: pinBorderColor,
                                ),
                              ),
                            ),
                          );
                        }),
                        if (_routeOrigin != null)
                          Marker(
                            point: _routeOrigin!,
                            width: 48,
                            height: 48,
                            child: const _OriginMarker(),
                          ),
                        if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
                            width: 58,
                            height: 58,
                            child: _PulsingLocationMarker(
                              animation: _locationPulseController,
                            ),
                          ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          '© CartoDB © OpenStreetMap contributors',
                          onTap: () => launchUrl(
                            Uri.parse('https://carto.com/attributions'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!_navigationActive) ...[
                  Positioned(
                    left: 14,
                    top: 14,
                    child: _MapStatusChip(
                      offlineReady: offlineTilesReady,
                      usingOfflineTiles: usingOfflineTiles,
                      attempted: _offlineTileLoadAttempted,
                      isOnline: _isOnline,
                    ),
                  ),
                  Positioned(
                    right: 14,
                    top: 14,
                    child: _MapControls(
                      onZoomIn: () => _zoomBy(1),
                      onZoomOut: () => _zoomBy(-1),
                      onReset: () => _mapController.move(_center, 8.6),
                      onLayers: () => unawaited(_showTileStyleSheet()),
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
                              key: const ValueKey('hint'),
                              color: cs.primary,
                            )
                          : _DestinationPreview(
                              key: ValueKey(_selectedDestination!.id),
                              destination: _selectedDestination!,
                              onClose: () =>
                                  setState(() => _selectedDestination = null),
                              onOpen: () =>
                                  _openDestination(_selectedDestination!),
                              onNavigate: () =>
                                  _openExternalMap(_selectedDestination!),
                            ),
                    ),
                  ),
                ],
                if (_navigationActive && _activeRoute != null)
                  NavigationOverlay(
                    route: _activeRoute!,
                    steps: _activeRoute!.steps,
                    currentStepIndex: _currentStepIndex,
                    currentPosition: _currentLocation,
                    destination: _destinationPoint(_routeDestination!)!,
                    onStepAdvance: () => setState(() {
                      if (_activeRoute != null &&
                          _currentStepIndex < _activeRoute!.steps.length - 1) {
                        _currentStepIndex++;
                      }
                    }),
                    onEndNavigation: () => unawaited(_endNavigation()),
                  ),
              ],
            ),
    );
  }
}

String _formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
  }
  return '${meters.round()} m';
}

String _formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) return '$hours hr';
  return '$hours hr $remainingMinutes min';
}

IconData _iconForTravelMode(TravelMode mode) {
  return switch (mode) {
    TravelMode.driving => Icons.directions_car_rounded,
    TravelMode.walking => Icons.directions_walk_rounded,
    TravelMode.cycling => Icons.directions_bike_rounded,
  };
}

class _RouteActionSheet extends StatelessWidget {
  final Destination destination;
  final RouteResult? route;
  final TravelMode selectedMode;
  final bool isLoading;
  final String? errorText;
  final Future<void> Function(TravelMode) onModeChanged;
  final Future<void> Function() onGetDirections;
  final Future<void> Function() onStartNavigation;
  final VoidCallback onOpenDetails;

  const _RouteActionSheet({
    required this.destination,
    required this.route,
    required this.selectedMode,
    required this.isLoading,
    required this.errorText,
    required this.onModeChanged,
    required this.onGetDirections,
    required this.onStartNavigation,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final category =
        destination.category.isNotEmpty ? destination.category.first : 'scenic';
    final color = AppTheme.categoryColourFor(context, category);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: 18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _kCategoryIcons[category.toLowerCase()] ??
                        Icons.place_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        destination.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'View details',
                  onPressed: onOpenDetails,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _RouteSummary(
              route: route,
              selectedMode: selectedMode,
              isLoading: isLoading,
              errorText: errorText,
            ),
            const SizedBox(height: 18),
            Row(
              children: TravelMode.values
                  .map(
                    (mode) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: mode == TravelMode.cycling ? 0 : 8,
                        ),
                        child: _TravelModeButton(
                          mode: mode,
                          selected: selectedMode == mode,
                          enabled: !isLoading,
                          onPressed: () => unawaited(onModeChanged(mode)),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    isLoading ? null : () => unawaited(onGetDirections()),
                icon: const Icon(Icons.route_rounded),
                label: const Text('Get Directions'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    isLoading ? null : () => unawaited(onStartNavigation()),
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Start Navigation'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  final RouteResult? route;
  final TravelMode selectedMode;
  final bool isLoading;
  final String? errorText;

  const _RouteSummary({
    required this.route,
    required this.selectedMode,
    required this.isLoading,
    required this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isLoading) {
      return Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 10),
          Text(
            'Calculating ${selectedMode.label.toLowerCase()} route...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      );
    }

    if (route != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RouteMetricChip(
                icon: Icons.straighten_rounded,
                label: _formatDistance(route!.distanceMeters),
              ),
              const SizedBox(width: 8),
              _RouteMetricChip(
                icon: Icons.schedule_rounded,
                label: _formatDuration(route!.durationSeconds),
              ),
            ],
          ),
          if (route!.isFallback) ...[
            const SizedBox(height: 8),
            Text(
              '⚠ Approximate route only',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.tertiary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ],
      );
    }

    return Text(
      errorText ?? 'Choose a travel mode, then get directions.',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: errorText == null ? cs.onSurfaceVariant : cs.error,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _RouteMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RouteMetricChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _TravelModeButton extends StatelessWidget {
  final TravelMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  const _TravelModeButton({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(_iconForTravelMode(mode), size: 18),
      label: Text(mode.label),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? cs.primary : cs.surface,
        foregroundColor: selected ? cs.onPrimary : cs.onSurface,
        side: BorderSide(
          color: selected ? cs.primary : cs.outlineVariant,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
    );
  }
}

class _OriginMarker extends StatelessWidget {
  const _OriginMarker();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF1976D2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.my_location_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: const _PinTailPainter(color: color),
        ),
      ],
    );
  }
}

class _PulsingLocationMarker extends StatelessWidget {
  final Animation<double> animation;

  const _PulsingLocationMarker({required this.animation});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF2196F3);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final radius = 8 + (animation.value * 12);
        final opacity = 0.28 * (1 - animation.value);

        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DestinationPin extends StatefulWidget {
  final String category;
  final bool isSelected;
  final Color borderColor;

  const _DestinationPin({
    required this.category,
    required this.borderColor,
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
    final color = AppTheme.categoryColourFor(context, widget.category);
    final foreground = AppTheme.foregroundFor(color);
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
              border: Border.all(color: widget.borderColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: foreground, size: 18),
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
  final VoidCallback onLayers;

  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.onLayers,
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
          Divider(color: cs.outlineVariant),
          _MapControlButton(
            icon: Icons.layers_rounded,
            onPressed: onLayers,
          ),
        ],
      ),
    );
  }
}

class _MapStatusChip extends StatelessWidget {
  final bool offlineReady;
  final bool usingOfflineTiles;
  final bool attempted;
  final bool isOnline;

  const _MapStatusChip({
    required this.offlineReady,
    required this.usingOfflineTiles,
    required this.attempted,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = usingOfflineTiles
        ? cs.tertiary
        : isOnline
            ? cs.secondary
            : cs.error;
    final label = usingOfflineTiles
        ? 'Offline map'
        : attempted
            ? (isOnline ? 'Online map' : 'Offline unavailable')
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
              usingOfflineTiles
                  ? Icons.offline_bolt_rounded
                  : isOnline
                      ? Icons.public_rounded
                      : Icons.cloud_off_rounded,
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
  final VoidCallback onNavigate;

  const _DestinationPreview({
    super.key,
    required this.destination,
    required this.onClose,
    required this.onOpen,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final category =
        destination.category.isNotEmpty ? destination.category.first : 'scenic';
    final color = AppTheme.categoryColourFor(context, category);

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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                        label: const Text('View details'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onNavigate,
                        icon: const Icon(Icons.near_me_rounded, size: 18),
                        label: const Text('Navigate'),
                      ),
                    ],
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
