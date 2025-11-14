import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/glowing_icon.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _ticker;
  DateTime? _maxSeenNowUtc;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadHighWaterClock();
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await _bumpHighWaterClock();
      setState(() {});
    }
  }

  Future<void> _loadHighWaterClock() async {
    final db = context.read<AlchemonsDatabase>();
    final s = await db.settingsDao.getSetting('max_seen_now_utc_ms');
    final ms = int.tryParse(s ?? '');
    _maxSeenNowUtc = (ms == null)
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    await _bumpHighWaterClock();
  }

  Future<void> _bumpHighWaterClock() async {
    final db = context.read<AlchemonsDatabase>();
    final nowUtc = DateTime.now().toUtc();
    if (_maxSeenNowUtc == null || nowUtc.isAfter(_maxSeenNowUtc!)) {
      _maxSeenNowUtc = nowUtc;
      await db.settingsDao.setSetting(
        'max_seen_now_utc_ms',
        nowUtc.millisecondsSinceEpoch.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          // dark lab console background with faint faction glow
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              theme.surface,
              theme.surface,
              theme.surfaceAlt.withOpacity(.6),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderBar(theme: theme, controller: _pulse),
              Expanded(
                // build button to lead to arena
                child: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (_) => const TeamPrepScreen(),
                      //   ),
                      // );
                    },
                    child: const Text('Warming up'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Loading / Error panels ----------------------------------------------

  Widget _buildLoadingScreen(FactionTheme theme, String message) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              theme.surface,
              theme.surface,
              theme.surfaceAlt.withOpacity(.6),
            ],
            stops: const [0, .6, 1],
          ),
        ),
        child: Center(
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withOpacity(.4),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(.8),
                  blurRadius: 40,
                  spreadRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(theme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(
    FactionTheme theme,
    String error,
    VoidCallback onRetry,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              theme.surface,
              theme.surface,
              theme.surfaceAlt.withOpacity(.6),
            ],
            stops: const [0, .6, 1],
          ),
        ),
        child: Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(.4), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.redAccent,
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SYSTEM ERROR DETECTED',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.redAccent.withOpacity(.9),
                          Colors.redAccent.withOpacity(.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(.4),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Text(
                      'RETRY CONNECTION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: .5,
                      ),
                    ),
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

// -----------------------------------------------------------------------------
// HEADER BAR
// -----------------------------------------------------------------------------

class _HeaderBar extends StatelessWidget {
  final FactionTheme theme;
  final AnimationController controller;

  const _HeaderBar({required this.theme, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Sticky chrome top
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        border: Border(bottom: BorderSide(color: theme.border, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: theme.accent.withOpacity(.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // left icon glow / info button
          //back button
          BackButton(color: theme.text),

          const SizedBox(width: 12),

          // title / subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CompeteScreen',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  'Alchemon battling center',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
