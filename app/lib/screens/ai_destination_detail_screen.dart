import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/backend_config.dart';
import '../main.dart' show userProfileService;
import '../models/accommodation_model.dart';
import '../models/api_recommendation_item.dart';
import '../models/destination.dart';
import '../services/recommendation_api_service.dart';
import '../widgets/accommodation_card.dart';
import '../widgets/destination_gallery.dart';
import '../widgets/score_breakdown_widget.dart';

class AiDestinationDetailScreen extends StatefulWidget {
  final ApiRecommendationItem item;

  const AiDestinationDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<AiDestinationDetailScreen> createState() =>
      _AiDestinationDetailScreenState();
}

class _AiDestinationDetailScreenState extends State<AiDestinationDetailScreen>
    with SingleTickerProviderStateMixin {
  late final RecommendationApiService _api;
  late final TabController _tabController;

  List<AccommodationModel> _accommodations = [];
  List<ApiRecommendationItem> _similar = [];
  bool _loadingAccommodations = true;
  bool _loadingSimilar = true;
  bool _backendOffline = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _api = RecommendationApiService(baseUrl: backendBaseUrl);
    _tabController = TabController(length: 3, vsync: this);
    _logView();
    _loadAccommodations();
    _loadSimilar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logView() async {
    try {
      final userId = await _currentUserId();
      await _api.logInteraction(
        userId: userId,
        destinationId: widget.item.id,
        eventType: 'detail_view',
      );
    } catch (_) {}
  }

  Future<void> _loadAccommodations() async {
    try {
      final accommodations = await _api
          .accommodations(widget.item.id)
          .timeout(const Duration(seconds: 8));
      if (!mounted) {
        return;
      }
      setState(() {
        _accommodations = accommodations;
        _loadingAccommodations = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backendOffline = true;
        _loadingAccommodations = false;
      });
    }
  }

  Future<void> _loadSimilar() async {
    try {
      final similar = await _api
          .similar(destinationId: widget.item.id, topK: 5)
          .timeout(const Duration(seconds: 8));
      if (!mounted) {
        return;
      }
      setState(() {
        _similar = similar;
        _loadingSimilar = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backendOffline = true;
        _loadingSimilar = false;
      });
    }
  }

  Future<void> _toggleSave() async {
    setState(() => _saved = !_saved);
    try {
      final userId = await _currentUserId();
      await _api.logInteraction(
        userId: userId,
        destinationId: widget.item.id,
        eventType: 'save',
      );
    } catch (_) {}

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _saved
              ? '${widget.item.name} saved to AI history.'
              : 'Removed saved flag.',
        ),
      ),
    );
  }

  Future<String> _currentUserId() async {
    try {
      return await userProfileService.stableUserId();
    } catch (_) {
      return 'anonymous';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) {
          return [
            SliverAppBar(
              pinned: true,
              expandedHeight: 300,
              backgroundColor: cs.primary,
              actions: [
                IconButton(
                  tooltip: 'Share destination',
                  icon: const Icon(
                    Icons.ios_share_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text: 'Check out ${item.name} in Nepal!\n'
                            '${item.reasons.isNotEmpty ? item.reasons.first : item.location}\n\n'
                            'Discover it on Rural Tourism Guide.',
                        subject: item.name,
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: _saved ? 'Remove from saved' : 'Save destination',
                  onPressed: _toggleSave,
                  icon: Icon(
                    _saved ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(item.name),
                background: DestinationGallery(
                  destination: item.destination,
                  height: 300,
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Stay'),
                  Tab(text: 'Similar'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(item: item),
            _buildAccommodationsTab(),
            _buildSimilarTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAccommodationsTab() {
    final cs = Theme.of(context).colorScheme;

    if (_loadingAccommodations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_accommodations.isEmpty && _backendOffline) {
      return _BackendOfflineState(
        message: 'Nearby stays not available without the AI server.',
        colorScheme: cs,
      );
    }

    if (_accommodations.isEmpty) {
      return const Center(
        child: Text('No accommodation data available for this destination.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      children: _accommodations
          .map((accommodation) =>
              AccommodationCard(accommodation: accommodation))
          .toList(),
    );
  }

  Widget _buildSimilarTab() {
    final cs = Theme.of(context).colorScheme;

    if (_loadingSimilar) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_similar.isEmpty && _backendOffline) {
      return _BackendOfflineState(
        message: 'Similar destinations not available without the AI server.',
        colorScheme: cs,
      );
    }

    if (_similar.isEmpty) {
      return const Center(
        child: Text('No similar destinations were returned by the backend.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _similar.map((item) {
        return Card(
          child: ListTile(
            leading: Icon(
              Icons.explore,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(item.name),
            subtitle: Text(
              item.location.isEmpty
                  ? 'AI recommended destination'
                  : item.location,
            ),
            trailing: Text('${(item.score * 100).toStringAsFixed(0)}%'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AiDestinationDetailScreen(item: item),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

class _BackendOfflineState extends StatelessWidget {
  final String message;
  final ColorScheme colorScheme;

  const _BackendOfflineState({
    required this.message,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text(
            'Backend offline',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

extension _ApiRecommendationDestination on ApiRecommendationItem {
  Destination get destination {
    final category = metadata['category'] ?? metadata['type'] ?? 'scenic';
    final description = reasons.isNotEmpty
        ? reasons.first
        : location.isNotEmpty
            ? location
            : 'AI recommended rural tourism destination.';

    return Destination(
      id: id,
      name: name,
      province: province ?? '',
      district: district,
      category: [category],
      activities: const [],
      bestSeason: const [],
      budgetLevel: budgetLevel.isEmpty ? null : budgetLevel,
      accessibility: accessibility.isEmpty ? null : accessibility,
      shortDescription: description,
      fullDescription: description,
      tags: const [],
      source: 'ai',
      confidence: 'medium',
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final ApiRecommendationItem item;

  const _OverviewTab({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (item.location.isNotEmpty)
          _InfoRow(icon: Icons.location_on, text: item.location),
        if (item.budgetLevel.isNotEmpty)
          _InfoRow(
              icon: Icons.payments_outlined,
              text: 'Budget: ${item.budgetLevel}'),
        if (item.accessibility.isNotEmpty)
          _InfoRow(
            icon: Icons.accessibility_new,
            text: 'Accessibility: ${item.accessibility}',
          ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Match Score',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${(item.score * 100).toStringAsFixed(1)}% match to the selected travel profile.',
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(item.score * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (item.reasons.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Why this was recommended',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...item.reasons.map(
            (reason) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              title: Text(reason),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ScoreBreakdownWidget(components: item.components),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
