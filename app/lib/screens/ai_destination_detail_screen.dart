import 'package:flutter/material.dart';

import '../core/utils/backend_config.dart';
import '../models/accommodation_model.dart';
import '../models/api_recommendation_item.dart';
import '../services/recommendation_api_service.dart';
import '../widgets/accommodation_card.dart';
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
      await _api.logInteraction(
        userId: 'demo_user_1',
        destinationId: widget.item.id,
        eventType: 'detail_view',
      );
    } catch (_) {}
  }

  Future<void> _loadAccommodations() async {
    try {
      final accommodations = await _api.accommodations(widget.item.id);
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
      setState(() => _loadingAccommodations = false);
    }
  }

  Future<void> _loadSimilar() async {
    try {
      final similar = await _api.similar(destinationId: widget.item.id, topK: 5);
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
      setState(() => _loadingSimilar = false);
    }
  }

  Future<void> _toggleSave() async {
    setState(() => _saved = !_saved);
    try {
      await _api.logInteraction(
        userId: 'demo_user_1',
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
          _saved ? '${widget.item.name} saved to AI history.' : 'Removed saved flag.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) {
          return [
            SliverAppBar(
              pinned: true,
              expandedHeight: 220,
              backgroundColor: const Color(0xFF1B5E20),
              actions: [
                IconButton(
                  onPressed: _toggleSave,
                  icon: Icon(
                    _saved ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(item.name),
                background: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1B5E20),
                        Color(0xFF4CAF50),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.landscape,
                      size: 84,
                      color: Colors.white24,
                    ),
                  ),
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
    if (_loadingAccommodations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_accommodations.isEmpty) {
      return const Center(
        child: Text('No accommodation data available for this destination.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      children: _accommodations
          .map((accommodation) => AccommodationCard(accommodation: accommodation))
          .toList(),
    );
  }

  Widget _buildSimilarTab() {
    if (_loadingSimilar) {
      return const Center(child: CircularProgressIndicator());
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
            leading: const Icon(Icons.explore, color: Color(0xFF2E7D32)),
            title: Text(item.name),
            subtitle: Text(
              item.location.isEmpty ? 'AI recommended destination' : item.location,
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
        if (item.location.isNotEmpty) _InfoRow(icon: Icons.location_on, text: item.location),
        if (item.budgetLevel.isNotEmpty)
          _InfoRow(icon: Icons.payments_outlined, text: 'Budget: ${item.budgetLevel}'),
        if (item.accessibility.isNotEmpty)
          _InfoRow(
            icon: Icons.accessibility_new,
            text: 'Accessibility: ${item.accessibility}',
          ),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFE8F5E9),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF2E7D32), size: 30),
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
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (item.reasons.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Why this was recommended', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...item.reasons.map(
            (reason) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF2E7D32),
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
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
