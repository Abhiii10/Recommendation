import 'package:flutter/material.dart';

import '../main.dart' show userProfileService;
import '../models/accommodation.dart';
import '../models/destination.dart';
import '../services/local_data_service.dart';
import '../services/offline_storage.dart';
import '../services/recommender_service.dart';
import 'home_tab.dart' as home;
import 'map_screen.dart';
import 'recommend_tab.dart' as recommend;
import 'saved_tab.dart';
import 'translation_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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

      final destinations = await OfflineStorage.loadDestinations();
      final accommodations = await OfflineStorage.loadAccommodations();
      final similarPlaces = await OfflineStorage.loadSimilarPlaces();
      final saved = await LocalDataService.instance.getSavedDestinations();

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gandaki Tourism Guide')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Could not load app data.\n\n$_error'),
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
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Recommend',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.translate_outlined),
            selectedIcon: Icon(Icons.translate),
            label: 'Translate',
          ),
        ],
      ),
    );
  }
}
