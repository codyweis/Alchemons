// screens/breed/breed_screen.dart
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:flutter/material.dart';

import 'package:alchemons/screens/breed/breed_tab.dart';
import 'package:alchemons/screens/breed/nursery_tab.dart';
import 'package:alchemons/services/game_data_service.dart';

/// Top-level shell for the breeding flow.
/// Uses TabBar (Nursery / Breed) for smooth navigation.
/// Integrates with withGameData() to supply live entries.
class BreedScreen extends StatefulWidget {
  const BreedScreen({super.key, this.title = 'Alchemons'});

  final String title;

  @override
  State<BreedScreen> createState() => _BreedScreenState();
}

class _BreedScreenState extends State<BreedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return withGameData(
      context,
      loadingBuilder: buildLoadingScreen,
      builder:
          (
            context, {
            required theme,
            required catalog,
            required entries,
            required discovered,
          }) {
            return Scaffold(
              backgroundColor: theme.surface,
              appBar: AppBar(
                title: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Cultivations'),
                    Tab(text: 'Fusion'),
                  ],
                ),
              ),

              body: TabBarView(
                controller: _tabController,
                children: [
                  NurseryTab(
                    maxSeenNowUtc: DateTime.now().toUtc(),
                    onHatchComplete: _noop,
                    onRequestAddEgg: () => _tabController.animateTo(1),
                  ),
                  BreedingTab(
                    discoveredCreatures: entries,
                    onBreedingComplete: _noop,
                  ),
                ],
              ),
            );
          },
    );
  }
}

void _noop() {}
