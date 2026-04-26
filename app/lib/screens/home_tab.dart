import 'dart:async';

import 'package:flutter/material.dart';

import '../models/destination.dart';
import '../theme/app_theme.dart';
import 'details_screen.dart';

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

IconData _iconFor(String cat) =>
    _kCategoryIcons[cat.toLowerCase()] ?? Icons.place_rounded;

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────
class HomeTab extends StatefulWidget {
  final List<Destination> destinations;
  final VoidCallback onOpenRecommend;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenSaved;

  const HomeTab({
    super.key,
    required this.destinations,
    required this.onOpenRecommend,
    required this.onOpenMap,
    required this.onOpenSaved,
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
  final List<String> _recentSearches = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
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
    if (_recentSearches.length > 5) _recentSearches.removeLast();
  }

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
      final as_ = a.tags.length + a.activities.length + a.category.length;
      final bs_ = b.tags.length + b.activities.length + b.category.length;
      return bs_.compareTo(as_);
    });
    return sorted.take(6).toList();
  }

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
    final rankedResults = _rankedResults;
    final hasFilter = _debouncedQuery.isNotEmpty || _activeCategory != null;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          pinned: true,
          expandedHeight: 300,
          backgroundColor: cs.surface,
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
                  'Nepal Tourism Guide',
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
                Image.asset('assets/images/pokhara.png', fit: BoxFit.cover),
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
                          fontFamily: 'Georgia',
                          height: 1.15,
                          letterSpacing: -0.5,
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
                        _activeCategory =
                            _activeCategory == cat ? null : cat;
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
                            builder: (_) => DetailsScreen(destination: d),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _SectionLabel(
                        text: 'All Destinations (${widget.destinations.length})',
                      ),
                      const SizedBox(height: 12),
                      ...widget.destinations.map((d) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CompactDestinationCard(
                            destination: d,
                            reason: 'Browse all destinations',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DetailsScreen(destination: d),
                              ),
                            ),
                            onMap: widget.onOpenMap,
                          ),
                        );
                      }),
                    ] else if (rankedResults.isEmpty) ...[
                      _EmptyResult(
                        query: _debouncedQuery,
                        category: _activeCategory,
                        featured: featured,
                        onTap: (d) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailsScreen(destination: d),
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
      ],
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
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
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search destination, district, activity…',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: cs.primary,
            size: 22,
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.cancel_rounded,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: onClear,
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
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category filter strip
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryStrip extends StatelessWidget {
  final List<String> categories;
  final String? active;
  final ValueChanged<String> onTap;

  const _CategoryStrip({
    required this.categories,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isActive = cat == active;
          final color = AppTheme.categoryColour(cat);

          return GestureDetector(
            onTap: () => onTap(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? color : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? color : const Color(0xFFD8DDD9),
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
                    color: isActive ? Colors.white : color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${cat[0].toUpperCase()}${cat.substring(1)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? Colors.white
                          : const Color(0xFF3A4040),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final String? sub;

  const _SectionLabel({
    required this.text,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: Theme.of(context).textTheme.titleMedium),
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
              child: Icon(icon, color: Colors.white, size: 20),
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
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF6B7676),
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
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: destinations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final d = destinations[i];
          final cat = d.category.isNotEmpty ? d.category.first : 'scenic';
          final color = AppTheme.categoryColour(cat);
          final icon = _iconFor(cat);

          return GestureDetector(
            onTap: () => onTap(d),
            child: Container(
              width: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.85),
                    color.withValues(alpha: 0.55),
                    color.withValues(alpha: 0.75),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    left: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        const Spacer(),
                        Text(
                          d.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Georgia',
                            shadows: [
                              Shadow(color: Colors.black26, blurRadius: 6),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.district ??
                              (d.category.isNotEmpty ? d.category.first : ''),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            d.bestSeasonText.isNotEmpty
                                ? d.bestSeasonText
                                : 'Year round',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
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

    final cat = destination.category.isNotEmpty
        ? destination.category.first
        : 'scenic';

    final color = AppTheme.categoryColour(cat);
    final icon = _iconFor(cat);

    final locationParts = [
      if ((destination.district ?? '').trim().isNotEmpty)
        destination.district!,
      if ((destination.municipality ?? '').trim().isNotEmpty)
        destination.municipality!,
    ];

    final previewTags = {
      ...destination.category,
      ...destination.activities,
    }.where((e) => e.trim().isNotEmpty).take(3).toList();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE0E6E2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 24,
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
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cs.error.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 36,
                color: cs.error,
              ),
              const SizedBox(height: 10),
              Text(
                'No results found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                query.isNotEmpty
                    ? 'Nothing matched "$query"${category != null ? ' in $category' : ''}. Try a different search.'
                    : 'No destinations in this category yet.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
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