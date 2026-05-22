import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show userProfileService;
import '../models/accommodation.dart';
import '../models/destination.dart';
import '../services/local_data_service.dart';
import '../services/image_cache_service.dart';
import '../services/offline_storage.dart';
import '../services/recommender_service.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton_card.dart';
import 'about_tab.dart';
import 'chatbot_screen.dart';
import 'home_tab.dart' as home;
import 'map_screen.dart';
import 'recommend_tab.dart' as recommend;
import 'saved_tab.dart';
import 'translation_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeMode;

  const DashboardScreen({
    super.key,
    required this.themeMode,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  bool _loading = true;
  String? _error;

  List<Destination> _destinations = [];
  List<Accommodation> _accommodations = [];
  List<Destination> _savedDestinations = [];

  RecommenderService? _service;

  @override
  void initState() {
    super.initState();
    _loadApp();
  }

  Future<void> _loadApp() async {
    try {
      await LocalDataService.instance.init();

      final loaded = await Future.wait<Object>([
        OfflineStorage.loadDestinations(),
        OfflineStorage.loadAccommodations(),
        OfflineStorage.loadSimilarPlaces(),
        LocalDataService.instance.getSavedDestinations(),
      ]);

      final destinations = loaded[0] as List<Destination>;
      final accommodations = loaded[1] as List<Accommodation>;
      final similarPlaces =
          loaded[2] as Map<String, List<Map<String, dynamic>>>;
      final saved = loaded[3] as List<Destination>;

      if (!mounted) return;

      setState(() {
        _destinations = destinations;
        _accommodations = accommodations;
        _service = RecommenderService(
          similarPlaces,
          userProfileService: userProfileService,
        );
        _savedDestinations = saved;
        _loading = false;
        _error = null;
      });

      _scheduleImageCacheWarmup(destinations);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _scheduleImageCacheWarmup(List<Destination> destinations) {
    final stableDestinations = List<Destination>.unmodifiable(destinations);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_warmImageCaches(stableDestinations));
    });
  }

  Future<void> _warmImageCaches(List<Destination> destinations) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    await ImageCacheService.instance.prefetchAll(destinations);
    if (!mounted) return;

    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    await ImageCacheService.instance.prefetchGalleries(destinations);
  }

  Future<void> _toggleSaved(Destination destination) async {
    final exists = _savedDestinations.any((d) => d.id == destination.id);
    if (exists) {
      await LocalDataService.instance.removeSavedDestination(destination.id);
    } else {
      await LocalDataService.instance.saveDestination(destination);
      await userProfileService.recordBookmark(destination);
    }
    final updated = await LocalDataService.instance.getSavedDestinations();
    if (!mounted) return;
    setState(() => _savedDestinations = updated);
  }

  bool _isSaved(Destination destination) =>
      _savedDestinations.any((d) => d.id == destination.id);

  void _goToTab(int index) => setState(() => _currentIndex = index);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();

    if (_error != null || _service == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.error_outline_rounded,
                        size: 36, color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 20),
                  Text('Could not load app data',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(_error ?? 'Unknown error',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                      maxLines: 4),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                      });
                      _loadApp();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final pages = [
      home.HomeTab(
        destinations: _destinations,
        onOpenRecommend: () => _goToTab(1),
        onOpenMap: () => _goToTab(2),
        onOpenSaved: () => _goToTab(3),
      ),
      recommend.RecommendTab(
        destinations: _destinations,
        accommodations: _accommodations,
        service: _service!,
        onToggleSaved: _toggleSaved,
        isSaved: _isSaved,
      ),
      MapScreen(
        destinations: _destinations,
        accommodations: _accommodations,
      ),
      SavedTab(
        savedDestinations: _savedDestinations,
        accommodations: _accommodations,
        onToggleSaved: _toggleSaved,
      ),
      const TranslationScreen(),
      ChatbotScreen(destinations: _destinations),
      AboutTab(themeMode: widget.themeMode),
    ];

    return Scaffold(
      body: OfflineBanner(
        child: IndexedStack(index: _currentIndex, children: pages),
      ),
      bottomNavigationBar: _AppNavBar(
        currentIndex: _currentIndex,
        savedCount: _savedDestinations.length,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Splash / loading screen
// ─────────────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.landscape_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nepal Tourism Guide',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Loading destinations...',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: SkeletonCard(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom nav bar
// ─────────────────────────────────────────────────────────────────────────────
class _AppNavBar extends StatelessWidget {
  final int currentIndex;
  final int savedCount;
  final ValueChanged<int> onTap;

  const _AppNavBar({
    required this.currentIndex,
    required this.savedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final barColor = cs.surface;
    final dividerColor = cs.outlineVariant.withValues(
      alpha: brightness == Brightness.dark ? 0.55 : 1,
    );
    final inactiveColor = cs.onSurfaceVariant;

    final items = <_NavItem>[
      const _NavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home'),
      const _NavItem(
          icon: Icons.auto_awesome_outlined,
          activeIcon: Icons.auto_awesome_rounded,
          label: 'Discover'),
      const _NavItem(
          icon: Icons.map_outlined,
          activeIcon: Icons.map_rounded,
          label: 'Map'),
      _NavItem(
        icon: Icons.bookmark_border_rounded,
        activeIcon: Icons.bookmark_rounded,
        label: 'Saved',
        badge: savedCount > 0 ? '$savedCount' : null,
      ),
      const _NavItem(
          icon: Icons.translate_outlined,
          activeIcon: Icons.translate_rounded,
          label: 'Translate'),
      const _NavItem(
          icon: Icons.chat_bubble_outline_rounded,
          activeIcon: Icons.chat_bubble_rounded,
          label: 'Chat'),
      const _NavItem(
          icon: Icons.info_outline_rounded,
          activeIcon: Icons.info_rounded,
          label: 'About'),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: barColor.withValues(
              alpha: brightness == Brightness.dark ? 0.84 : 0.75,
            ),
            border: Border(top: BorderSide(color: dividerColor, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: brightness == Brightness.dark ? 0.24 : 0.05,
                ),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 68,
              child: Row(
                children: items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final isActive = idx == currentIndex;
                  final color = isActive ? cs.primary : inactiveColor;

                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: isActive,
                      label: item.label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onTap(idx);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? cs.primaryContainer
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isActive ? item.activeIcon : item.icon,
                                    color: color,
                                    size: 22,
                                  ),
                                ),
                                if (item.badge != null)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.error,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        item.badge!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badge;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      this.badge});
}
