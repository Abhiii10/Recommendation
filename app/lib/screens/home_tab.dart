import 'dart:async';

import 'package:flutter/material.dart';

import '../models/destination.dart';
import 'details_screen.dart';

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
  final List<String> _recentSearches = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    setState(() {
      _query = value;
    });

    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;

      setState(() {
        _debouncedQuery = value.trim();
      });

      if (value.trim().isNotEmpty) {
        _saveRecentSearch(value.trim());
      }
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
    final normalized = value.trim();
    if (normalized.isEmpty) return;

    _recentSearches.removeWhere(
      (item) => item.toLowerCase() == normalized.toLowerCase(),
    );

    _recentSearches.insert(0, normalized);

    if (_recentSearches.length > 5) {
      _recentSearches.removeLast();
    }
  }

  void _applySuggestion(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );

    _debounce?.cancel();

    setState(() {
      _query = value;
      _debouncedQuery = value;
    });

    _saveRecentSearch(value);
  }

  List<String> get _suggestionChips {
    final suggestions = <String>{};

    for (final d in widget.destinations) {
      if (d.category.isNotEmpty) {
        suggestions.add(d.category.first);
      }
      if (d.activities.isNotEmpty) {
        suggestions.add(d.activities.first);
      }
      if (d.tags.isNotEmpty) {
        suggestions.add(d.tags.first);
      }
    }

    return suggestions.where((e) => e.trim().isNotEmpty).take(8).toList();
  }

  List<Destination> get _featuredDestinations {
    final sorted = [...widget.destinations];

    sorted.sort((a, b) {
      final aScore = a.tags.length + a.activities.length + a.category.length;
      final bScore = b.tags.length + b.activities.length + b.category.length;
      return bScore.compareTo(aScore);
    });

    return sorted.take(3).toList();
  }

  List<_ScoredDestination> get _rankedResults {
    final q = _debouncedQuery.trim().toLowerCase();
    if (q.isEmpty) return [];

    final scored = <_ScoredDestination>[];

    for (final d in widget.destinations) {
      final score = _calculateScore(d, q);
      if (score > 0) {
        scored.add(_ScoredDestination(destination: d, score: score));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.destination.name.toLowerCase().compareTo(
            b.destination.name.toLowerCase(),
          );
    });

    return scored;
  }

  int _calculateScore(Destination d, String q) {
    int score = 0;

    final name = d.name.toLowerCase();
    final district = (d.district ?? '').toLowerCase();
    final municipality = (d.municipality ?? '').toLowerCase();
    final shortDescription = d.shortDescription.toLowerCase();
    final fullDescription = d.fullDescription.toLowerCase();

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

    if (shortDescription.contains(q)) score += 12;
    if (fullDescription.contains(q)) score += 6;

    return score;
  }

  String _matchReason(Destination d, String q) {
    final lowerQ = q.toLowerCase();

    if (d.name.toLowerCase().contains(lowerQ)) {
      return 'Matched by destination name';
    }
    if ((d.district ?? '').toLowerCase().contains(lowerQ)) {
      return 'Matched by district';
    }
    if ((d.municipality ?? '').toLowerCase().contains(lowerQ)) {
      return 'Matched by municipality';
    }
    if (d.category.any((e) => e.toLowerCase().contains(lowerQ))) {
      return 'Matched by category';
    }
    if (d.activities.any((e) => e.toLowerCase().contains(lowerQ))) {
      return 'Matched by activity';
    }
    if (d.tags.any((e) => e.toLowerCase().contains(lowerQ))) {
      return 'Matched by tag';
    }
    return 'Matched by description';
  }

  @override
  Widget build(BuildContext context) {
    final featured = _featuredDestinations;
    final rankedResults = _rankedResults;
    final visibleResults = rankedResults.take(12).toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          pinned: true,
          expandedHeight: 280,
          title: const Text('Rural Tourism Guide'),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/pokhara.png',
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Text(
                    'Discover rural destinations around Gandaki through recommendations, maps, and curated local insights.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _controller,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText:
                            'Search destinations, district, tag, or activity...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_query.isEmpty) ...[
                      if (_recentSearches.isNotEmpty) ...[
                        Text(
                          'Recent searches',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _recentSearches
                              .map(
                                (item) => ActionChip(
                                  label: Text(item),
                                  onPressed: () => _applySuggestion(item),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Quick suggestions',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestionChips
                            .map(
                              (item) => ActionChip(
                                label: Text(item),
                                onPressed: () => _applySuggestion(item),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explore the app',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Use recommendations to find matching destinations, explore places on the map, and save destinations for later.',
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 420;
                                return GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: isNarrow ? 0.82 : 0.98,
                                  children: [
                                    _QuickActionCard(
                                      icon: Icons.explore_outlined,
                                      title: 'Get Recommendations',
                                      subtitle:
                                          'Find places based on preferences',
                                      onTap: widget.onOpenRecommend,
                                    ),
                                    _QuickActionCard(
                                      icon: Icons.map_outlined,
                                      title: 'Explore Map',
                                      subtitle: 'View destinations on map',
                                      onTap: widget.onOpenMap,
                                    ),
                                    _QuickActionCard(
                                      icon: Icons.bookmark_outline,
                                      title: 'Saved Places',
                                      subtitle: 'Revisit your shortlist',
                                      onTap: widget.onOpenSaved,
                                    ),
                                    _QuickActionCard(
                                      icon: Icons.travel_explore_outlined,
                                      title: 'Rural Tourism',
                                      subtitle:
                                          'Discover authentic local experiences',
                                      onTap: widget.onOpenRecommend,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _debouncedQuery.isEmpty
                          ? 'Featured destinations'
                          : 'Search results (${rankedResults.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_debouncedQuery.isEmpty)
                      ...featured.map(
                        (d) => _destinationCard(
                          context,
                          d,
                          reason: 'Featured destination',
                        ),
                      )
                    else if (rankedResults.isEmpty)
                      _emptyState(context, _debouncedQuery)
                    else ...[
                      ...visibleResults.map(
                        (item) => _destinationCard(
                          context,
                          item.destination,
                          reason:
                              _matchReason(item.destination, _debouncedQuery),
                        ),
                      ),
                      if (rankedResults.length > visibleResults.length)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Showing top ${visibleResults.length} results out of ${rankedResults.length}. Refine your search for better matches.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
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

  Widget _emptyState(BuildContext context, String query) {
    final featured = _featuredDestinations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No results found',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nothing matched "$query". Try a destination name, district, activity, or category.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Try these featured destinations',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...featured.map(
          (d) => _destinationCard(
            context,
            d,
            reason: 'Suggested featured destination',
          ),
        ),
      ],
    );
  }

  Widget _destinationCard(
    BuildContext context,
    Destination d, {
    required String reason,
  }) {
    final locationParts = [
      if ((d.district ?? '').trim().isNotEmpty) d.district!.trim(),
      if ((d.municipality ?? '').trim().isNotEmpty) d.municipality!.trim(),
    ];

    final locationText = locationParts.isEmpty
        ? 'Location not available'
        : locationParts.join(' • ');

    final previewTags = [
      ...d.category,
      ...d.activities,
      ...d.tags,
    ].where((e) => e.trim().isNotEmpty).take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailsScreen(
                  destination: d,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: const Icon(Icons.terrain_outlined),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        locationText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.primaryCategory} • ${d.bestSeasonText}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reason,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        d.shortDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (previewTags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: previewTags
                              .map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetailsScreen(
                                    destination: d,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('View details'),
                          ),
                          OutlinedButton.icon(
                            onPressed: widget.onOpenMap,
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Open map'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoredDestination {
  final Destination destination;
  final int score;

  const _ScoredDestination({
    required this.destination,
    required this.score,
  });
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 16),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}