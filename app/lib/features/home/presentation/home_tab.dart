import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/shared/theme/app_theme.dart';
import 'package:rural_tourism_app/features/destinations/domain/services/accommodation_matcher.dart';
import 'package:rural_tourism_app/features/destinations/presentation/widgets/destination_image.dart';
import 'package:rural_tourism_app/shared/widgets/empty_state_widget.dart';
import 'package:rural_tourism_app/features/destinations/presentation/details_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Category icon map
// ─────────────────────────────────────────────────────────────────────────────
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
  'social': Icons.people_rounded,
};

const _recentSearchesKey = 'recent_searches';
const _recentSearchTimestampsKey = 'recent_search_timestamps';
const _recentSearchMaxAge = Duration(days: 30);

IconData _iconFor(String cat) =>
    _kCategoryIcons[cat.toLowerCase()] ?? Icons.place_rounded;

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────
class HomeTab extends StatefulWidget {
  final List<Destination> destinations;
  final List<Accommodation> accommodations;
  final VoidCallback onOpenRecommend;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenSaved;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenAbout;

  const HomeTab({
    super.key,
    required this.destinations,
    required this.accommodations,
    required this.onOpenRecommend,
    required this.onOpenMap,
    required this.onOpenSaved,
    this.onOpenAccount,
    this.onOpenAbout,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _debouncedQuery = '';
  String? _activeCategory;
  List<String> _recentSearches = [];
  Map<String, int> _recentSearchTimestamps = {};
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecentSearches());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final searches = prefs.getStringList(_recentSearchesKey) ?? [];
    final timestamps = _loadRecentSearchTimestamps(prefs);
    final activeSearches = <String>[];
    final activeTimestamps = <String, int>{};

    for (final search in searches) {
      final normalized = search.trim();
      if (normalized.isEmpty) continue;

      final key = _recentSearchKey(normalized);
      final timestamp = timestamps[key] ?? now.millisecondsSinceEpoch;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);

      if (now.difference(savedAt) > _recentSearchMaxAge) {
        continue;
      }

      activeSearches.add(normalized);
      activeTimestamps[key] = timestamp;
    }

    unawaited(
      Future.wait([
        prefs.setStringList(_recentSearchesKey, activeSearches),
        prefs.setString(
          _recentSearchTimestampsKey,
          jsonEncode(activeTimestamps),
        ),
      ]),
    );

    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _recentSearches = activeSearches;
      _recentSearchTimestamps = activeTimestamps;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value);
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _debouncedQuery = value.trim());
      if (value.trim().isNotEmpty) _saveRecentSearch(value.trim());
    });
  }

  void _clearSearch() {
    HapticFeedback.lightImpact();
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _query = '';
      _debouncedQuery = '';
    });
  }

  void _saveRecentSearch(String value) {
    final n = value.trim();
    if (n.isEmpty) return;
    _recentSearches.removeWhere((e) => e.toLowerCase() == n.toLowerCase());
    _recentSearches.insert(0, n);
    _recentSearchTimestamps[_recentSearchKey(n)] =
        DateTime.now().millisecondsSinceEpoch;
    if (_recentSearches.length > 5) {
      final removed = _recentSearches.removeLast();
      _recentSearchTimestamps.remove(_recentSearchKey(removed));
    }
    _persistRecentSearches();
  }

  Map<String, int> _loadRecentSearchTimestamps(SharedPreferences prefs) {
    final raw = prefs.getString(_recentSearchTimestampsKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) {
        final timestamp = value is int ? value : int.tryParse('$value') ?? 0;
        return MapEntry(key, timestamp);
      });
    } catch (_) {
      return {};
    }
  }

  void _persistRecentSearches() {
    final prefs = _prefs;
    if (prefs == null) return;

    unawaited(
      Future.wait([
        prefs.setStringList(_recentSearchesKey, _recentSearches),
        prefs.setString(
          _recentSearchTimestampsKey,
          jsonEncode(_recentSearchTimestamps),
        ),
      ]),
    );
  }

  String _recentSearchKey(String value) => value.trim().toLowerCase();

  void _applySuggestion(String value) {
    _controller.text = value;
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: value.length));
    _debounce?.cancel();
    setState(() {
      _query = value;
      _debouncedQuery = value;
    });
    _saveRecentSearch(value);
  }

  List<String> get _allCategories {
    final cats = <String>{};
    for (final d in widget.destinations) {
      for (final c in d.category) {
        if (c.trim().isNotEmpty) cats.add(c);
      }
    }
    return cats.take(10).toList();
  }

  List<Destination> get _featuredDestinations {
    final sorted = [...widget.destinations];
    sorted.sort((a, b) {
      final scoreCompare = _featuredScore(b).compareTo(_featuredScore(a));
      return scoreCompare != 0
          ? scoreCompare
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted.take(6).toList();
  }

  double _featuredScore(Destination destination) {
    final adventureScore =
        ((destination.adventureLevel ?? 0).clamp(0, 5) / 5) * 0.3;
    final activityScore =
        (destination.activities.length.clamp(0, 10) / 10) * 0.3;
    final tagScore = (destination.tags.length.clamp(0, 15) / 15) * 0.2;
    final familyScore = destination.familyFriendly == true ? 0.2 : 0.0;

    return adventureScore + activityScore + tagScore + familyScore;
  }

  String get _currentSeason {
    final month = DateTime.now().month;
    if (month == 12 || month <= 2) return 'winter';
    if (month <= 5) return 'spring';
    if (month <= 8) return 'summer';
    return 'autumn';
  }

  List<Destination> _bestThisSeasonDestinations(String season) {
    final lowerSeason = season.toLowerCase();
    return widget.destinations
        .where(
          (destination) => destination.bestSeason.any(
            (value) => value.toLowerCase().contains(lowerSeason),
          ),
        )
        .toList();
  }

  IconData _seasonIcon(String season) {
    switch (season) {
      case 'spring':
        return Icons.local_florist_rounded;
      case 'summer':
        return Icons.wb_sunny_rounded;
      case 'autumn':
        return Icons.forest_rounded;
      case 'winter':
        return Icons.ac_unit_rounded;
      default:
        return Icons.calendar_month_rounded;
    }
  }

  String _seasonLabel(String season) => season.isEmpty
      ? season
      : '${season[0].toUpperCase()}${season.substring(1)}';

  List<_ScoredDestination> get _rankedResults {
    final q = _debouncedQuery.trim().toLowerCase();
    if (q.isEmpty && _activeCategory == null) return [];

    final scored = <_ScoredDestination>[];

    for (final d in widget.destinations) {
      final passesCategory = _activeCategory == null ||
          d.category.any(
            (c) => c.toLowerCase() == _activeCategory!.toLowerCase(),
          );

      if (!passesCategory) continue;

      final score = q.isEmpty ? 1 : _calculateScore(d, q);

      if (score > 0) {
        scored.add(_ScoredDestination(destination: d, score: score));
      }
    }

    scored.sort((a, b) {
      final s = b.score.compareTo(a.score);
      return s != 0
          ? s
          : a.destination.name
              .toLowerCase()
              .compareTo(b.destination.name.toLowerCase());
    });

    return scored;
  }

  int _calculateScore(Destination d, String q) {
    int score = 0;

    final name = d.name.toLowerCase();
    final district = (d.district ?? '').toLowerCase();
    final municipality = (d.municipality ?? '').toLowerCase();
    final shortDesc = d.shortDescription.toLowerCase();
    final fullDesc = d.fullDescription.toLowerCase();
    final categories = d.category.map((e) => e.toLowerCase()).toList();
    final activities = d.activities.map((e) => e.toLowerCase()).toList();
    final tags = d.tags.map((e) => e.toLowerCase()).toList();

    if (name == q) score += 120;
    if (name.startsWith(q)) score += 80;
    if (name.contains(q)) score += 60;

    if (district == q) score += 45;
    if (district.contains(q)) score += 25;

    if (municipality == q) score += 45;
    if (municipality.contains(q)) score += 25;

    for (final item in categories) {
      if (item == q) {
        score += 40;
      } else if (item.contains(q)) {
        score += 20;
      }
    }

    for (final item in activities) {
      if (item == q) {
        score += 36;
      } else if (item.contains(q)) {
        score += 18;
      }
    }

    for (final item in tags) {
      if (item == q) {
        score += 32;
      } else if (item.contains(q)) {
        score += 16;
      }
    }

    if (shortDesc.contains(q)) score += 12;
    if (fullDesc.contains(q)) score += 6;

    return score;
  }

  String _matchReason(Destination d, String q) {
    final lq = q.toLowerCase();

    if (d.name.toLowerCase().contains(lq)) {
      return 'Matched destination name';
    }

    if ((d.district ?? '').toLowerCase().contains(lq)) {
      return 'Matched district';
    }

    if ((d.municipality ?? '').toLowerCase().contains(lq)) {
      return 'Matched municipality';
    }

    if (d.category.any((e) => e.toLowerCase().contains(lq))) {
      return 'Matched category';
    }

    if (d.activities.any((e) => e.toLowerCase().contains(lq))) {
      return 'Matched activity';
    }

    if (d.tags.any((e) => e.toLowerCase().contains(lq))) {
      return 'Matched tag';
    }

    return 'Matched description';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final featured = _featuredDestinations;
    final currentSeason = _currentSeason;
    final seasonalDestinations = _bestThisSeasonDestinations(currentSeason);
    final rankedResults = _rankedResults;
    final hasFilter = _debouncedQuery.isNotEmpty || _activeCategory != null;

    return DecoratedBox(
      decoration: AppTheme.scaffoldDecorationFor(context),
      child: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: cs.surface,
            actions: [
              if (widget.onOpenAccount != null)
                IconButton(
                  tooltip: 'Account',
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: widget.onOpenAccount,
                ),
              if (widget.onOpenAbout != null)
                IconButton(
                  tooltip: 'About',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: widget.onOpenAbout,
                ),
            ],
            title: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.landscape_rounded,
                    color: cs.onPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Paila Nepal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/pokhara_hero.webp',
                    fit: BoxFit.cover,
                    cacheWidth: 1600,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.30),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 20,
                    right: 20,
                    bottom: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Discover Rural Nepal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Outfit',
                            height: 1.15,
                            letterSpacing: 0,
                            shadows: [
                              Shadow(color: Colors.black38, blurRadius: 12),
                            ],
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Hidden villages · Sacred trails · Authentic culture',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SearchBar(
                        controller: _controller,
                        query: _query,
                        onChanged: _onSearchChanged,
                        onClear: _clearSearch,
                      ),
                      const SizedBox(height: 14),
                      _CategoryStrip(
                        categories: _allCategories,
                        active: _activeCategory,
                        onTap: (cat) => setState(() {
                          _activeCategory = _activeCategory == cat ? null : cat;
                        }),
                      ),
                      const SizedBox(height: 20),
                      if (_query.isEmpty && _recentSearches.isNotEmpty) ...[
                        _SectionLabel(text: 'Recent searches'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _recentSearches.map((item) {
                            return ActionChip(
                              avatar: Icon(
                                Icons.history_rounded,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              label: Text(item),
                              onPressed: () => _applySuggestion(item),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (!hasFilter) ...[
                        _SectionLabel(text: 'Explore the app'),
                        const SizedBox(height: 12),
                        _QuickActionRow(
                          onRecommend: widget.onOpenRecommend,
                          onMap: widget.onOpenMap,
                          onSaved: widget.onOpenSaved,
                        ),
                        const SizedBox(height: 28),
                      ],
                      if (!hasFilter) ...[
                        _SectionLabel(text: 'Featured Destinations'),
                        const SizedBox(height: 12),
                        _FeaturedCarousel(
                          destinations: featured,
                          onTap: (d) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailsScreen(
                                destination: d,
                                nearbyAccommodations:
                                    accommodationsForDestination(
                                  d,
                                  widget.accommodations,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (seasonalDestinations.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _SectionLabel(
                            text: 'Best This Season',
                            sub: 'Ideal for ${_seasonLabel(currentSeason)}',
                            icon: _seasonIcon(currentSeason),
                          ),
                          const SizedBox(height: 12),
                          _SeasonalDestinationRail(
                            destinations: seasonalDestinations,
                            onTap: (d) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailsScreen(
                                  destination: d,
                                  nearbyAccommodations:
                                      accommodationsForDestination(
                                    d,
                                    widget.accommodations,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        _SectionLabel(
                          text:
                              'All Destinations (${widget.destinations.length})',
                        ),
                        const SizedBox(height: 12),
                      ] else if (rankedResults.isEmpty) ...[
                        _EmptyResult(
                          query: _debouncedQuery,
                          category: _activeCategory,
                          featured: featured,
                          onTap: (d) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailsScreen(
                                destination: d,
                                nearbyAccommodations:
                                    accommodationsForDestination(
                                  d,
                                  widget.accommodations,
                                ),
                              ),
                            ),
                          ),
                          onMap: widget.onOpenMap,
                        ),
                      ] else ...[
                        _SectionLabel(
                          text: 'Results (${rankedResults.length})',
                          sub: _activeCategory != null
                              ? 'Filtered by $_activeCategory'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        ...rankedResults.take(14).map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CompactDestinationCard(
                              destination: item.destination,
                              reason: _debouncedQuery.isNotEmpty
                                  ? _matchReason(
                                      item.destination,
                                      _debouncedQuery,
                                    )
                                  : 'Filtered by $_activeCategory',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetailsScreen(
                                    destination: item.destination,
                                    nearbyAccommodations:
                                        accommodationsForDestination(
                                      item.destination,
                                      widget.accommodations,
                                    ),
                                  ),
                                ),
                              ),
                              onMap: widget.onOpenMap,
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!hasFilter)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.builder(
                itemCount: widget.destinations.length,
                itemBuilder: (context, index) {
                  final destination = widget.destinations[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CompactDestinationCard(
                          destination: destination,
                          reason: 'Browse all destinations',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailsScreen(
                                destination: destination,
                                nearbyAccommodations:
                                    accommodationsForDestination(
                                  destination,
                                  widget.accommodations,
                                ),
                              ),
                            ),
                          ),
                          onMap: widget.onOpenMap,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: isDark ? 0.92 : 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cs.outlineVariant,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: TextStyle(fontSize: 15, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Search destination, district, activity...',
              hintStyle: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.58),
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: cs.primary,
                size: 22,
              ),
              suffixIcon: query.isNotEmpty
                  ? Semantics(
                      label: 'Clear search',
                      button: true,
                      child: IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(
                          Icons.cancel_rounded,
                          color: cs.onSurfaceVariant,
                          size: 20,
                        ),
                        onPressed: onClear,
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: cs.primary, width: 1.8),
              ),
              filled: true,
              fillColor: cs.surface.withValues(alpha: isDark ? 0.98 : 0.72),
            ),
          ),
        ),
      ),
    );
  }
}

// Category filter strip
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryStrip extends StatefulWidget {
  final List<String> categories;
  final String? active;
  final ValueChanged<String> onTap;

  const _CategoryStrip({
    required this.categories,
    required this.active,
    required this.onTap,
  });

  @override
  State<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<_CategoryStrip> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snapToNearestChip() {
    if (!_controller.hasClients) return;
    const chipWidth = 110.0;
    final max = _controller.position.maxScrollExtent;
    final nearest =
        ((_controller.offset / chipWidth).round() * chipWidth).clamp(0.0, max);
    _controller.animateTo(
      nearest,
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 42,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            _snapToNearestChip();
          }
          return false;
        },
        child: ListView.separated(
          controller: _controller,
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          itemCount: widget.categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = widget.categories[i];
            final isActive = cat == widget.active;
            final color = AppTheme.categoryColourFor(context, cat);
            final foreground = AppTheme.foregroundFor(color);

            return AnimatedScale(
              scale: isActive ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onTap(cat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? color : cs.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isActive ? color : cs.outlineVariant,
                      width: isActive ? 0 : 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconFor(cat),
                        size: 14,
                        color: isActive ? foreground : color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${cat[0].toUpperCase()}${cat.substring(1)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive ? foreground : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final String? sub;
  final IconData? icon;

  const _SectionLabel({
    required this.text,
    this.sub,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: cs.onPrimaryContainer, size: 18),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (sub != null)
                Text(
                  sub!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick action row
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionRow extends StatelessWidget {
  final VoidCallback onRecommend;
  final VoidCallback onMap;
  final VoidCallback onSaved;

  const _QuickActionRow({
    required this.onRecommend,
    required this.onMap,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final tiles = [
      _ActionTile(
        icon: Icons.auto_awesome_rounded,
        label: 'AI Pick',
        subtitle: 'Get smart recommendations',
        color: cs.primary,
        onTap: onRecommend,
      ),
      _ActionTile(
        icon: Icons.map_rounded,
        label: 'Map',
        subtitle: 'Explore destinations visually',
        color: AppTheme.highlandSage,
        onTap: onMap,
      ),
      _ActionTile(
        icon: Icons.bookmark_rounded,
        label: 'Saved',
        subtitle: 'Your shortlisted places',
        color: AppTheme.earthOchre,
        onTap: onSaved,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            children: [
              tiles[0],
              const SizedBox(height: 10),
              tiles[1],
              const SizedBox(height: 10),
              tiles[2],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 10),
            Expanded(child: tiles[1]),
            const SizedBox(width: 10),
            Expanded(child: tiles[2]),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconForeground = AppTheme.foregroundFor(color);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconForeground, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: cs.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured horizontal carousel
// ─────────────────────────────────────────────────────────────────────────────
class _FeaturedCarousel extends StatelessWidget {
  final List<Destination> destinations;
  final ValueChanged<Destination> onTap;

  const _FeaturedCarousel({
    required this.destinations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();

    final hero = destinations.first;
    final rest = destinations.skip(1).take(4).toList();

    return Column(
      children: [
        _FeaturedHeroCard(destination: hero, onTap: () => onTap(hero)),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rest.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemBuilder: (context, index) {
              final destination = rest[index];
              return _FeaturedMiniCard(
                destination: destination,
                onTap: () => onTap(destination),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _SeasonalDestinationRail extends StatelessWidget {
  final List<Destination> destinations;
  final ValueChanged<Destination> onTap;

  const _SeasonalDestinationRail({
    required this.destinations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 206,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: destinations.length,
        itemBuilder: (context, index) {
          final destination = destinations[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index == destinations.length - 1 ? 0 : 12,
            ),
            child: SizedBox(
              width: 156,
              child: HeroMode(
                enabled: false,
                child: _FeaturedMiniCard(
                  destination: destination,
                  onTap: () => onTap(destination),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeaturedHeroCard extends StatelessWidget {
  final Destination destination;
  final VoidCallback onTap;

  const _FeaturedHeroCard({
    required this.destination,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cat =
        destination.category.isNotEmpty ? destination.category.first : 'scenic';
    final color = AppTheme.categoryColourFor(context, cat);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _FeaturedImage(destination: destination, height: 200),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.52),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Text(
                      destination.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                        shadows: [
                          Shadow(color: Colors.black38, blurRadius: 10)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _FeaturedCategoryChip(category: cat, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedMiniCard extends StatelessWidget {
  final Destination destination;
  final VoidCallback onTap;

  const _FeaturedMiniCard({
    required this.destination,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: _FeaturedImage(destination: destination, height: 120),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                destination.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedImage extends StatelessWidget {
  final Destination destination;
  final double height;

  const _FeaturedImage({
    required this.destination,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'dest-image-${destination.id}',
      child: DestinationImage(
        destination: destination,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _FeaturedCategoryChip extends StatelessWidget {
  final String category;
  final Color color;

  const _FeaturedCategoryChip({
    required this.category,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(category), size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            '${category[0].toUpperCase()}${category.substring(1)}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// Compact destination card
// ─────────────────────────────────────────────────────────────────────────────
class _CompactDestinationCard extends StatelessWidget {
  final Destination destination;
  final String reason;
  final VoidCallback onTap;
  final VoidCallback onMap;

  const _CompactDestinationCard({
    required this.destination,
    required this.reason,
    required this.onTap,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final cat =
        destination.category.isNotEmpty ? destination.category.first : 'scenic';

    final color = AppTheme.categoryColourFor(context, cat);
    final locationParts = [
      if ((destination.district ?? '').trim().isNotEmpty) destination.district!,
      if ((destination.municipality ?? '').trim().isNotEmpty)
        destination.municipality!,
    ];

    final previewTags = {
      ...destination.category,
      ...destination.activities,
    }.where((e) => e.trim().isNotEmpty).take(3).toList();

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cs.outlineVariant,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: DestinationImage(
                          destination: destination,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destination.name,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          if (locationParts.isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 12,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    locationParts.join(' · '),
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 6),
                          Text(
                            destination.shortDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(height: 1.45),
                          ),
                          if (previewTags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: previewTags.map((tag) {
                                return ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 120,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 24,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty result state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyResult extends StatelessWidget {
  final String query;
  final String? category;
  final List<Destination> featured;
  final ValueChanged<Destination> onTap;
  final VoidCallback onMap;

  const _EmptyResult({
    required this.query,
    required this.category,
    required this.featured,
    required this.onTap,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = query.isNotEmpty
        ? 'No trail matched "$query"${category != null ? ' in $category' : ''}. Try another signpost.'
        : 'This category is as quiet as a hill village after sunset. Try another filter.';

    return Column(
      children: [
        EmptyStateWidget(
          title: 'No results found',
          subtitle: subtitle,
          icon: Icons.search_off_rounded,
          actionLabel: 'Open Map',
          onAction: onMap,
        ),
        const SizedBox(height: 20),
        const _SectionLabel(text: 'Try these instead'),
        const SizedBox(height: 12),
        ...featured.take(3).map((d) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CompactDestinationCard(
              destination: d,
              reason: 'Suggested featured destination',
              onTap: () => onTap(d),
              onMap: onMap,
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal data class
// ─────────────────────────────────────────────────────────────────────────────
class _ScoredDestination {
  final Destination destination;
  final int score;

  const _ScoredDestination({
    required this.destination,
    required this.score,
  });
}
