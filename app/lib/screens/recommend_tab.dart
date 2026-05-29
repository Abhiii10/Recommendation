import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/accommodation.dart';
import '../models/destination.dart';
import '../models/unified_recommendation.dart';
import '../services/local_data_service.dart';
import '../services/recommendation_manager.dart';
import '../services/recommender_service.dart';
import '../theme/app_theme.dart';
import '../utils/accommodation_matcher.dart';
import '../widgets/destination_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/score_breakdown_widget.dart';
import '../widgets/skeleton_card.dart';
import 'ai_destination_detail_screen.dart';
import 'details_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour + icon maps for activity and vibe chips
// ─────────────────────────────────────────────────────────────────────────────
const _kActivityColours = {
  'trekking': Color(0xFF2E7D32),
  'culture': Color(0xFF6A1B9A),
  'relaxation': Color(0xFF0277BD),
  'adventure': Color(0xFFE65100),
  'photography': Color(0xFF00838F),
  'pilgrimage': Color(0xFF558B2F),
  'wildlife': Color(0xFF4E342E),
  'boating': Color(0xFF1565C0),
};

const _kActivityIcons = {
  'trekking': Icons.hiking_rounded,
  'culture': Icons.account_balance_rounded,
  'relaxation': Icons.spa_rounded,
  'adventure': Icons.terrain_rounded,
  'photography': Icons.camera_alt_rounded,
  'pilgrimage': Icons.temple_hindu_rounded,
  'wildlife': Icons.forest_rounded,
  'boating': Icons.sailing_rounded,
};

const _kVibeIcons = {
  'cultural': Icons.museum_rounded,
  'adventure': Icons.bolt_rounded,
  'peaceful': Icons.self_improvement_rounded,
  'spiritual': Icons.brightness_5_rounded,
  'scenic': Icons.landscape_rounded,
  'historic': Icons.domain_rounded,
  'nature': Icons.eco_rounded,
  'social': Icons.people_rounded,
};

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────
class RecommendTab extends StatefulWidget {
  final List<Destination> destinations;
  final List<Accommodation> accommodations;
  final RecommenderService service;
  final Future<void> Function(Destination) onToggleSaved;
  final bool Function(Destination) isSaved;
  final VoidCallback? onOpenAbout;

  const RecommendTab({
    super.key,
    required this.destinations,
    required this.accommodations,
    required this.service,
    required this.onToggleSaved,
    required this.isSaved,
    this.onOpenAbout,
  });

  @override
  State<RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<RecommendTab> {
  // ── options ───────────────────────────────────────────────────────────────
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
  static const budgetOptions = ['budget', 'medium', 'premium'];
  static const seasonOptions = ['spring', 'summer', 'autumn', 'winter'];
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

  // ── state ─────────────────────────────────────────────────────────────────
  late final RecommendationManager _manager;

  String activity = 'trekking';
  String budget = 'medium';
  String season = 'spring';
  String vibe = 'cultural';
  bool familyFriendly = false;
  int adventureLevel = 3;
  bool _showOnlySaved = false;

  bool _busy = false;
  bool _checkingBackend = true;
  bool _backendAvailable = false;
  String? _error;
  UnifiedRecommendationResponse? _response;

  // ── lifecycle ─────────────────────────────────────────────────────────────
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

  // ── helpers ───────────────────────────────────────────────────────────────
  Color _actColor() => AppTheme.categoryColourFor(context, activity);

  String _cap(String v) =>
      v.isEmpty ? v : '${v[0].toUpperCase()}${v.substring(1)}';

  List<UnifiedRecommendationResult> get _visible {
    final r = _response?.results ?? const [];
    return _showOnlySaved
        ? r.where((x) => widget.isSaved(x.destination)).toList()
        : r;
  }

  List<String> _badges(UnifiedRecommendationResult r, int idx) {
    final b = <String>[];
    final c = r.components;
    final stayCount = _staysFor(r.destination).length;
    if (idx == 0 || r.score >= 0.82) {
      b.add('Best Match');
    }
    if (r.mode == RecommendationMode.offline) {
      b.add('Offline Ready');
    }
    if (c.semantic >= 0.78) {
      b.add('Semantic Match');
    }
    if (c.budgetMatch >= 0.9) {
      b.add('Budget Friendly');
    }
    if (c.seasonMatch >= 0.9) {
      b.add('Seasonal Pick');
    }
    if (c.familyFit >= 0.9 && r.destination.familyFriendly == true) {
      b.add('Family Friendly');
    }
    if (c.accommodationFit >= 0.75) {
      b.add('Has Accommodation');
    }
    if (stayCount > 0) {
      b.add('$stayCount Stays Nearby');
    }
    if (c.semantic >= 0.7 && c.collaborative < 0.1) {
      b.add('Hidden Gem');
    }
    return b.take(4).toList();
  }

  List<Accommodation> _staysFor(Destination destination) {
    return accommodationsForDestination(destination, widget.accommodations);
  }

  IconData _modeIcon(RecommendationMode mode) {
    switch (mode) {
      case RecommendationMode.ai:
        return Icons.auto_awesome_rounded;
      case RecommendationMode.cached:
        return Icons.history_rounded;
      case RecommendationMode.offline:
        return Icons.offline_bolt_rounded;
    }
  }

  // ── actions ───────────────────────────────────────────────────────────────
  Future<void> _refreshBackendStatus() async {
    setState(() => _checkingBackend = true);
    final ok = await _manager.isBackendAvailable();
    if (!mounted) return;
    setState(() {
      _backendAvailable = ok;
      _checkingBackend = false;
    });
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _manager.recommend(
        activity: activity,
        budget: budget,
        season: season,
        vibe: vibe,
        familyFriendly: familyFriendly,
        adventureLevel: adventureLevel,
        topK: 10,
      );
      if (!mounted) return;
      setState(() {
        _response = r;
        _busy = false;
        _backendAvailable = r.mode == RecommendationMode.ai;
      });
      unawaited(_manager.logRecommendationShown(r.results));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not generate recommendations.\n\n$e';
      });
    }
  }

  Future<void> _refreshResults() async {
    await LocalDataService.instance.clearRecommendationCache();
    await _generate();
  }

  Future<void> _saveResult(UnifiedRecommendationResult r) async {
    final wasSaved = widget.isSaved(r.destination);
    await widget.onToggleSaved(r.destination);
    try {
      await _manager.logSave(r, saved: !wasSaved);
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleAndRefresh(Destination d) async {
    HapticFeedback.lightImpact();
    await widget.onToggleSaved(d);
    if (!mounted) return;
    setState(() {});
  }

  // ── build helpers ─────────────────────────────────────────────────────────

  /// Animated top banner showing AI vs offline mode
  Widget _buildModeBanner() {
    final cs = Theme.of(context).colorScheme;
    final isAI = _response?.mode == RecommendationMode.ai ||
        (_response == null && _backendAvailable);
    final color = isAI ? cs.primary : cs.tertiary;
    final icon = isAI ? Icons.auto_awesome_rounded : Icons.offline_bolt_rounded;
    final label = _response?.indicatorLabel ??
        (_checkingBackend
            ? 'Checking backend...'
            : _backendAvailable
                ? 'AI Online Mode Ready'
                : 'Advanced Offline Mode Ready');
    final body = _response?.message ??
        (_checkingBackend
            ? 'Checking whether the AI backend is reachable.'
            : _backendAvailable
                ? 'Online AI is ready. Offline semantic fallback is also available.'
                : '${widget.destinations.length} Gandaki places and ${widget.accommodations.length} stays are ready offline.');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.04)
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 2),
            Text(body,
                style: TextStyle(
                    color: color.withValues(alpha: 0.75),
                    fontSize: 12,
                    height: 1.4)),
          ],
        )),
        IconButton(
          onPressed: _refreshBackendStatus,
          icon: Icon(Icons.refresh_rounded, color: color, size: 20),
          tooltip: 'Refresh status',
        ),
      ]),
    );
  }

  /// Coloured pill chips with optional icon per option
  Widget _buildDimension({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    Map<String, IconData>? icons,
    Map<String, Color>? colours,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final sel = opt == selected;
              final color = colours != null
                  ? AppTheme.categoryColourFor(context, opt)
                  : cs.primary;
              final foreground = AppTheme.foregroundFor(color);
              final icon = icons?[opt];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => onSelected(opt));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel
                        ? color
                        : cs.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: sel ? color : cs.outlineVariant,
                        width: sel ? 0 : 1),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]
                        : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[
                      Icon(icon,
                          size: 15,
                          color: sel ? foreground : cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                    ],
                    Text(_cap(opt),
                        style: TextStyle(
                          color: sel ? foreground : cs.onSurface,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        )),
                  ]),
                ),
              );
            }).toList()),
      ],
    );
  }

  Widget _buildSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        )),
        Switch(
          value: value,
          onChanged: (next) {
            HapticFeedback.selectionClick();
            onChanged(next);
          },
        ),
      ]),
    );
  }

  Widget _buildFilterCard() {
    final cs = Theme.of(context).colorScheme;
    const adventureLabels = [
      'Easy',
      'Light',
      'Moderate',
      'Challenging',
      'Extreme'
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.tune_rounded, color: cs.primary, size: 22),
            const SizedBox(width: 10),
            Text('Recommendation Studio',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Tune your travel profile. The app tries AI first, falls back offline automatically.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 22),
          _buildDimension(
              title: 'Activity',
              options: activityOptions,
              selected: activity,
              onSelected: (v) => activity = v,
              icons: _kActivityIcons,
              colours: _kActivityColours),
          const SizedBox(height: 18),
          _buildDimension(
              title: 'Budget',
              options: budgetOptions,
              selected: budget,
              onSelected: (v) => budget = v),
          const SizedBox(height: 18),
          _buildDimension(
              title: 'Season',
              options: seasonOptions,
              selected: season,
              onSelected: (v) => season = v),
          const SizedBox(height: 18),
          _buildDimension(
              title: 'Trip vibe',
              options: vibeOptions,
              selected: vibe,
              onSelected: (v) => vibe = v,
              icons: _kVibeIcons),
          const SizedBox(height: 22),

          // Adventure level slider
          Row(children: [
            Icon(Icons.terrain_rounded, size: 18, color: _actColor()),
            const SizedBox(width: 8),
            Text('Adventure level: ',
                style: Theme.of(context).textTheme.titleSmall),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                adventureLabels[adventureLevel - 1],
                key: ValueKey(adventureLevel),
                style: TextStyle(
                    color: _actColor(),
                    fontWeight: FontWeight.w800,
                    fontSize: 13),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _AdventureSlider(
            value: adventureLevel,
            label: adventureLabels[adventureLevel - 1],
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => adventureLevel = value);
            },
          ),

          _buildSwitch(
              icon: Icons.family_restroom_rounded,
              title: 'Family friendly',
              subtitle: 'Prioritise destinations suitable for children.',
              value: familyFriendly,
              onChanged: (v) => setState(() => familyFriendly = v)),
          _buildSwitch(
              icon: Icons.bookmark_rounded,
              title: 'Show only saved results',
              subtitle: 'Filter the list to bookmarked places only.',
              value: _showOnlySaved,
              onChanged: (v) => setState(() => _showOnlySaved = v)),

          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _actColor(),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _busy
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      unawaited(_generate());
                    },
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                _busy ? 'Generating recommendations...' : 'Get Recommendations',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// Score ring replaces flat badge — shows progress filled to score value
  Widget _buildScoreRing(double score) {
    final color = _actColor();
    final pct = (score * 100).round();
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(fit: StackFit.expand, children: [
        CircularProgressIndicator(
          value: score,
          strokeWidth: 4,
          backgroundColor: color.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation(color),
        ),
        Center(
            child: Text('$pct',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: color))),
      ]),
    );
  }

  Widget _buildResultCard(UnifiedRecommendationResult result, int idx) {
    final saved = widget.isSaved(result.destination);
    final stays = _staysFor(result.destination);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DestinationCard(
        destination: result.destination,
        reasons: result.reasons,
        scoreLabel: '${(result.score * 100).round()}%',
        modeLabel: result.modeLabel,
        modeIcon: _modeIcon(result.mode),
        badges: _badges(result, idx),
        trailing: _buildScoreRing(result.score),
        insight: _RecommendationInsightStrip(
          result: result,
          accommodations: stays,
          color: AppTheme.categoryColourFor(
            context,
            result.destination.primaryCategory,
          ),
        ),
        isSaved: saved,
        onToggleSaved: () => _saveResult(result),
        footer: ScoreBreakdownWidget(
          components: result.components,
          compact: false,
          title: 'Active score signals',
        ),
        onTap: () {
          unawaited(_manager.logClick(result));
          if (result.isAiBacked) {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AiDestinationDetailScreen(item: result.aiItem!),
                ));
            return;
          }
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailsScreen(
                  destination: result.destination,
                  nearbyAccommodations: accommodationsForDestination(
                    result.destination,
                    widget.accommodations,
                  ),
                  isSaved: saved,
                  onToggleSaved: () => _toggleAndRefresh(result.destination),
                ),
              ));
        },
      ),
    );
  }

  Widget _buildSummaryRow() {
    final cs = Theme.of(context).colorScheme;
    final count = _visible.length;
    final saved = _visible.where((r) => widget.isSaved(r.destination)).length;
    final mode = _response?.indicatorLabel ?? 'Not run';

    return Row(children: [
      _StatPill(
          icon: Icons.explore_outlined,
          label: 'Results',
          value: '$count',
          color: cs.primary),
      const SizedBox(width: 10),
      _StatPill(
          icon: Icons.memory_rounded,
          label: 'Mode',
          value: mode,
          color: cs.secondary),
      const SizedBox(width: 10),
      _StatPill(
          icon: Icons.bookmark_outline_rounded,
          label: 'Saved',
          value: '$saved',
          color: cs.tertiary),
    ]);
  }

  Widget _buildInitialState() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: cs.primaryContainer, shape: BoxShape.circle),
            child:
                Icon(Icons.travel_explore_rounded, size: 36, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text('Discover Nepal\'s hidden gems',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
              'Set your activity, budget, season and vibe above,\nthen tap Get Recommendations.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const [
                _InfoPill(label: 'Semantic'),
                _InfoPill(label: 'Stays'),
                _InfoPill(label: 'Rerank'),
                _InfoPill(label: 'Explain'),
              ]),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      title: _showOnlySaved
          ? 'No saved results matched this profile'
          : 'No results matched this profile',
      subtitle: _showOnlySaved
          ? 'Your saved list has not found this trail yet. Show all results or bookmark more places first.'
          : 'The recommender found mist on this pass. Try changing the activity, season, budget, or vibe.',
      icon: Icons.search_off_rounded,
      actionLabel: _showOnlySaved ? 'Show All Results' : null,
      onAction: _showOnlySaved
          ? () => setState(() {
                _showOnlySaved = false;
              })
          : null,
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, index) => Padding(
        padding: EdgeInsets.only(bottom: index == 2 ? 0 : 14),
        child: const SkeletonCard(),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_busy) return _buildSkeleton();
    if (_response == null) return _buildInitialState();
    if (_visible.isEmpty) return _buildEmptyState();

    final response = _response!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (response.usedFallback) ...[
        _FallbackBanner(
            message:
                'Using semantic offline recommendations from local destination and stay data.'),
        const SizedBox(height: 14),
      ],
      _buildSummaryRow(),
      const SizedBox(height: 20),
      ..._visible.asMap().entries.map((e) => _buildResultCard(e.value, e.key)),
    ]);
  }

  // ── main build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        centerTitle: false,
        actions: [
          if (widget.onOpenAbout != null)
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'About',
              onPressed: widget.onOpenAbout,
            ),
          if (_error != null)
            IconButton(
              icon: const Icon(Icons.warning_amber_rounded),
              color: theme.colorScheme.error,
              tooltip: 'View error',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Error'),
                  content: Text(_error!),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'))
                  ],
                ),
              ),
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: AppTheme.scaffoldDecorationFor(context),
        child: RefreshIndicator(
          onRefresh: _refreshResults,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModeBanner(),
                        const SizedBox(height: 16),
                        _buildFilterCard(),
                        const SizedBox(height: 20),
                        if (_response != null || _busy) ...[
                          Row(children: [
                            Text('Ranked destinations',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const Spacer(),
                            Text('${_visible.length} results',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ]),
                          const SizedBox(height: 14),
                        ],
                        _buildResultsSection(),
                      ]),
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
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AdventureSlider extends StatelessWidget {
  final int value;
  final String label;
  final ValueChanged<int> onChanged;

  const _AdventureSlider({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final left = ((value - 1) / 4) * (availableWidth - 48);

        return SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left.clamp(0.0, availableWidth - 78),
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.mountainTeal,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.mountainTeal.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '$value - $label',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6,
                    activeTrackColor: AppTheme.mountainTeal,
                    inactiveTrackColor: AppTheme.mistGray,
                    thumbColor: AppTheme.mountainTeal,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 12),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 24),
                    valueIndicatorShape:
                        const PaddleSliderValueIndicatorShape(),
                    valueIndicatorColor: AppTheme.mountainTeal,
                    valueIndicatorTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    showValueIndicator: ShowValueIndicator.onDrag,
                  ),
                  child: Slider(
                    value: value.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$value - $label',
                    onChanged: (next) => onChanged(next.round()),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatPill(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, color: color)),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  const _InfoPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  final String message;
  const _FallbackBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.offline_bolt_rounded, color: cs.onTertiaryContainer),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onTertiaryContainer,
                    fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _RecommendationInsightStrip extends StatelessWidget {
  final UnifiedRecommendationResult result;
  final List<Accommodation> accommodations;
  final Color color;

  const _RecommendationInsightStrip({
    required this.result,
    required this.accommodations,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topSignals = [...result.components.signals()]
      ..sort((a, b) => b.value.compareTo(a.value));
    final visibleSignals = topSignals.take(3).toList();
    final topStay = accommodations.isEmpty ? null : accommodations.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InsightMetric(
                icon: Icons.percent_rounded,
                label: 'Match',
                value: '${(result.score * 100).round()}%',
                color: color,
              ),
              _InsightMetric(
                icon: result.mode == RecommendationMode.offline
                    ? Icons.offline_bolt_rounded
                    : result.mode == RecommendationMode.cached
                        ? Icons.history_rounded
                        : Icons.auto_awesome_rounded,
                label: 'Mode',
                value: _modeLabel(result.mode),
                color: color,
              ),
              _InsightMetric(
                icon: Icons.bed_rounded,
                label: 'Stays',
                value: accommodations.isEmpty
                    ? 'None listed'
                    : '${accommodations.length} nearby',
                color: color,
              ),
            ],
          ),
          if (topStay != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hotel_rounded, size: 17, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Best nearby stay: ${topStay.name}${_stayMeta(topStay)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.35,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ],
          if (visibleSignals.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: visibleSignals.map((signal) {
                return _SignalChip(
                  label: signal.label,
                  value: signal.value,
                  color: color,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _modeLabel(RecommendationMode mode) {
    switch (mode) {
      case RecommendationMode.ai:
        return 'AI';
      case RecommendationMode.cached:
        return 'Cached';
      case RecommendationMode.offline:
        return 'Offline';
    }
  }

  String _stayMeta(Accommodation stay) {
    final parts = [
      stay.type,
      stay.priceRange,
    ]
        .where((value) => value != null && value.trim().isNotEmpty)
        .cast<String>()
        .map(_titleCase)
        .toList();
    return parts.isEmpty ? '' : ' - ${parts.join(', ')}';
  }

  String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }
}

class _InsightMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InsightMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SignalChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${(value * 100).round()}%',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
      ),
    );
  }
}
