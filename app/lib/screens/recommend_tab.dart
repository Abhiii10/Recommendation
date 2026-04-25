import 'dart:async';

import 'package:flutter/material.dart';

import '../models/accommodation.dart';
import '../models/destination.dart';
import '../models/unified_recommendation.dart';
import '../services/recommendation_manager.dart';
import '../services/recommender_service.dart';
import '../widgets/destination_card.dart';
import '../widgets/score_breakdown_widget.dart';
import 'ai_destination_detail_screen.dart';
import 'details_screen.dart';

class RecommendTab extends StatefulWidget {
  final List<Destination> destinations;
  final List<Accommodation> accommodations;
  final RecommenderService service;
  final Future<void> Function(Destination) onToggleSaved;
  final bool Function(Destination) isSaved;

  const RecommendTab({
    super.key,
    required this.destinations,
    required this.accommodations,
    required this.service,
    required this.onToggleSaved,
    required this.isSaved,
  });

  @override
  State<RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<RecommendTab> {
  static const activityOptions = [
    'trekking',
    'culture',
    'relaxation',
    'adventure',
    'photography',
    'pilgrimage',
    'wildlife',
    'boating',
  ];

  static const budgetOptions = [
    'budget',
    'medium',
    'premium',
  ];

  static const seasonOptions = [
    'spring',
    'summer',
    'autumn',
    'winter',
  ];

  static const vibeOptions = [
    'cultural',
    'adventure',
    'peaceful',
    'spiritual',
    'scenic',
    'historic',
    'nature',
    'social',
  ];

  late final RecommendationManager _manager;

  String activity = 'trekking';
  String budget = 'medium';
  String season = 'spring';
  String vibe = 'cultural';
  bool familyFriendly = false;
  int adventureLevel = 3;

  bool _busy = false;
  bool _checkingBackend = true;
  bool _backendAvailable = false;
  bool _showOnlySaved = false;
  String? _error;
  UnifiedRecommendationResponse? _response;

  @override
  void initState() {
    super.initState();
    _manager = RecommendationManager(
      offlineService: widget.service,
      destinations: widget.destinations,
      accommodations: widget.accommodations,
    );
    unawaited(_refreshBackendStatus());
  }

  Future<void> _refreshBackendStatus() async {
    setState(() => _checkingBackend = true);

    final available = await _manager.isBackendAvailable();
    if (!mounted) {
      return;
    }

    setState(() {
      _backendAvailable = available;
      _checkingBackend = false;
    });
  }

  Future<void> _generateRecommendations() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await _manager.recommend(
        activity: activity,
        budget: budget,
        season: season,
        vibe: vibe,
        familyFriendly: familyFriendly,
        adventureLevel: adventureLevel,
        topK: 10,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _response = response;
        _busy = false;
        _backendAvailable = response.mode == RecommendationMode.ai;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _error = 'Could not generate recommendations.\n\n$error';
      });
    }
  }

  Future<void> _toggleSavedAndRefresh(Destination destination) async {
    await widget.onToggleSaved(destination);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _saveResult(UnifiedRecommendationResult result) async {
    await widget.onToggleSaved(result.destination);

    try {
      await _manager.logSave(result);
    } catch (_) {}

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  List<UnifiedRecommendationResult> get _visibleResults {
    final results = _response?.results ?? const <UnifiedRecommendationResult>[];
    if (!_showOnlySaved) {
      return results;
    }
    return results
        .where((result) => widget.isSaved(result.destination))
        .toList();
  }

  String _labelize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  String _scoreLabel(UnifiedRecommendationResult result) {
    return '${(result.score * 100).toStringAsFixed(0)}%';
  }

  List<String> _qualityBadges(
    UnifiedRecommendationResult result,
    int index,
  ) {
    final badges = <String>[];
    final components = result.components;

    if (index == 0 || result.score >= 0.82) {
      badges.add('Best Match');
    }
    if (components.budgetMatch >= 0.9) {
      badges.add('Budget Friendly');
    }
    if (components.seasonMatch >= 0.9) {
      badges.add('Seasonal Pick');
    }
    if (components.familyFit >= 0.9 && result.destination.familyFriendly == true) {
      badges.add('Family Friendly');
    }
    if (components.accommodationFit >= 0.75) {
      badges.add('Accommodation Available');
    }
    if (components.semantic >= 0.7 && components.collaborative < 0.1) {
      badges.add('Hidden Gem');
    }

    return badges.take(4).toList();
  }

  Widget _buildChoiceChips({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            return ChoiceChip(
              label: Text(_labelize(option)),
              selected: option == selected,
              onSelected: (_) => setState(() => onSelected(option)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildModeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final response = _response;
    final onlineActive =
        response?.mode == RecommendationMode.ai || (response == null && _backendAvailable);
    final toneColor = onlineActive ? colorScheme.primary : colorScheme.tertiary;
    final badgeLabel = response?.indicatorLabel ??
        (_checkingBackend
            ? 'Checking backend'
            : _backendAvailable
                ? 'AI Online Mode Ready'
                : 'Advanced Offline Mode Ready');

    final bodyText = response?.message ??
        (_checkingBackend
            ? 'Checking whether the backend AI recommender is reachable.'
            : _backendAvailable
                ? 'The backend is available, so recommendations will use the AI pipeline first.'
                : 'The backend is not reachable right now, but the advanced offline recommender is ready.');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              toneColor.withValues(alpha: 0.14),
              colorScheme.surface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: toneColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          onlineActive
                              ? Icons.auto_awesome_rounded
                              : Icons.offline_bolt_rounded,
                          size: 18,
                          color: toneColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          badgeLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: toneColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _refreshBackendStatus,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh status'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Advanced recommendation pipeline',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bodyText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _InfoPill(label: 'Retrieve'),
                  _InfoPill(label: 'Score'),
                  _InfoPill(label: 'Rerank'),
                  _InfoPill(label: 'Explain'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendation Studio',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tune the travel profile below. The app will try the online AI recommender first and automatically fall back to the advanced offline engine when needed.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _buildChoiceChips(
              title: 'Activity',
              options: activityOptions,
              selected: activity,
              onSelected: (value) => activity = value,
            ),
            const SizedBox(height: 16),
            _buildChoiceChips(
              title: 'Budget',
              options: budgetOptions,
              selected: budget,
              onSelected: (value) => budget = value,
            ),
            const SizedBox(height: 16),
            _buildChoiceChips(
              title: 'Season',
              options: seasonOptions,
              selected: season,
              onSelected: (value) => season = value,
            ),
            const SizedBox(height: 16),
            _buildChoiceChips(
              title: 'Trip vibe',
              options: vibeOptions,
              selected: vibe,
              onSelected: (value) => vibe = value,
            ),
            const SizedBox(height: 18),
            Text(
              'Adventure level: $adventureLevel / 5',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Slider(
              value: adventureLevel.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (value) {
                setState(() => adventureLevel = value.round());
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Family friendly'),
              subtitle: const Text(
                'Use this when the trip should prioritize family-friendly places.',
              ),
              value: familyFriendly,
              onChanged: (value) => setState(() => familyFriendly = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show only saved results'),
              subtitle: const Text(
                'Filter the generated list down to places already bookmarked.',
              ),
              value: _showOnlySaved,
              onChanged: (value) => setState(() => _showOnlySaved = value),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _generateRecommendations,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(_busy ? 'Generating recommendations...' : 'Generate Recommendations'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final response = _response;
    final resultCount = _visibleResults.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendation Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  label: 'Results',
                  value: '$resultCount',
                  icon: Icons.explore_outlined,
                ),
                _MetricTile(
                  label: 'Mode used',
                  value: response?.indicatorLabel ?? 'Not run',
                  icon: Icons.memory_rounded,
                ),
                _MetricTile(
                  label: 'Saved in list',
                  value: _visibleResults
                      .where((result) => widget.isSaved(result.destination))
                      .length
                      .toString(),
                  icon: Icons.bookmark_outline_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SelectionChip(label: 'Activity', value: _labelize(activity)),
                _SelectionChip(label: 'Budget', value: _labelize(budget)),
                _SelectionChip(label: 'Season', value: _labelize(season)),
                _SelectionChip(label: 'Vibe', value: _labelize(vibe)),
                _SelectionChip(
                  label: 'Adventure',
                  value: '$adventureLevel/5',
                ),
                if (familyFriendly)
                  const _SelectionChip(label: 'Family', value: 'Enabled'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackBanner() {
    final response = _response;
    if (response == null || !response.usedFallback) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.55),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.offline_bolt_rounded,
            color: colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Using advanced offline recommendations. The backend AI service was unavailable for this run.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 40,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Generate a recommendation profile',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select your activity, budget, season, and vibe, then generate recommendations to see one unified ranked list with explainable score factors.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              _showOnlySaved
                  ? 'No saved recommendations matched this profile'
                  : 'No recommendations matched this profile',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _showOnlySaved
                  ? 'Try turning off "Show only saved results" or bookmark more places first.'
                  : 'Try changing the activity, season, budget, or vibe to broaden the result set.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 14),
          child: const _LoadingRecommendationCard(),
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(
    UnifiedRecommendationResult result,
    int index,
  ) {
    final saved = widget.isSaved(result.destination);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DestinationCard(
        destination: result.destination,
        reasons: result.reasons,
        scoreLabel: _scoreLabel(result),
        modeLabel: result.modeLabel,
        modeIcon: result.mode == RecommendationMode.ai
            ? Icons.auto_awesome_rounded
            : Icons.offline_bolt_rounded,
        badges: _qualityBadges(result, index),
        trailing: IconButton.filledTonal(
          tooltip: saved ? 'Remove from saved' : 'Save destination',
          onPressed: () => _saveResult(result),
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
        ),
        footer: ScoreBreakdownWidget(
          components: result.components,
          compact: true,
          title: 'Active score signals',
        ),
        onTap: () {
          if (result.isAiBacked) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AiDestinationDetailScreen(item: result.aiItem!),
              ),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailsScreen(
                destination: result.destination,
                nearbyAccommodations: widget.accommodations,
                isSaved: widget.isSaved(result.destination),
                onToggleSaved: () => _toggleSavedAndRefresh(result.destination),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_busy) {
      return _buildLoadingState();
    }

    if (_response == null) {
      return _buildInitialState();
    }

    if (_visibleResults.isEmpty) {
      return _buildEmptyState();
    }

    final response = _response!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (response.usedFallback) ...[
          _buildFallbackBanner(),
          const SizedBox(height: 14),
        ],
        ..._visibleResults.asMap().entries.map(
              (entry) => _buildRecommendationCard(entry.value, entry.key),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recommendations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeCard(),
                  const SizedBox(height: 16),
                  _buildFilterCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                  const SizedBox(height: 18),
                  Text(
                    'Ranked destinations',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'One unified result list with explainable recommendation signals.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildResultsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;

  const _InfoPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  final String label;
  final String value;

  const _SelectionChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _LoadingRecommendationCard extends StatelessWidget {
  const _LoadingRecommendationCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget line(double width, {double height = 12}) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line(120, height: 28),
                      const SizedBox(height: 10),
                      line(double.infinity),
                      const SizedBox(height: 8),
                      line(180),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 72,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            line(double.infinity),
            const SizedBox(height: 8),
            line(double.infinity),
            const SizedBox(height: 8),
            line(220),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  line(double.infinity),
                  const SizedBox(height: 8),
                  line(double.infinity),
                  const SizedBox(height: 8),
                  line(180),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
