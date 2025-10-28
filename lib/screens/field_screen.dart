// lib/screens/field_screen.dart
import 'dart:math' as math;
import 'package:alchemons/screens/competition_hub_screen.dart';
import 'package:alchemons/screens/harvest_screen.dart';
import 'package:alchemons/screens/map_screen.dart';
import 'package:alchemons/screens/harvest_screen.dart' show BiomeHarvestScreen;
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/game_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class FieldScreen extends StatefulWidget {
  const FieldScreen({super.key, this.onOpenExpeditions, this.onOpenHarvest});

  /// If you already have screens wired, pass callbacks.
  /// Otherwise, this screen will fall back to Navigator.push.
  final VoidCallback? onOpenExpeditions;
  final VoidCallback? onOpenHarvest;

  @override
  State<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends State<FieldScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  void _goExpeditions() {
    HapticFeedback.selectionClick();
    if (widget.onOpenExpeditions != null) {
      widget.onOpenExpeditions!();
    } else {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => const MapScreen(),
          fullscreenDialog: true,
        ),
      );
    }
  }

  void _goHarvest() {
    HapticFeedback.selectionClick();
    if (widget.onOpenHarvest != null) {
      widget.onOpenHarvest!();
    } else {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => const BiomeHarvestScreen(),
          fullscreenDialog: true,
        ),
      );
    }
  }

  void _goCompetitions() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const CompetitionHubScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    final theme = context.watch<FactionTheme>();

    return Scaffold(
      // match HomeScreen loading/error bg fallback
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              // Header block (like HomeScreen header vibe, but local to this screen)
              _FieldHeader(theme: theme),
              const SizedBox(height: 16),

              // Content scroll
              Expanded(
                child: AnimatedBuilder(
                  animation: _floatCtrl,
                  builder: (context, _) {
                    final cards = [
                      _FieldActionCard(
                        title: 'Expeditions',
                        subtitle: 'Send a team on a mission',
                        icon: Icons.explore_rounded,
                        color: theme.accent, // use accent for icon chip
                        pillA: 'Open',
                        pillB: 'Field Map',
                        onTap: _goExpeditions,
                        floatPhase: _floatCtrl.value,
                      ),
                      _FieldActionCard(
                        title: 'Resource Harvesting',
                        subtitle: 'Gather field materials & samples',
                        icon: Icons.agriculture_rounded,
                        color: Colors.greenAccent.shade400.withOpacity(0.8),
                        pillA: 'Open',
                        pillB: 'Extract',
                        onTap: _goHarvest,
                        floatPhase: (_floatCtrl.value + 0.33) % 1.0,
                      ),
                      _FieldActionCard(
                        title: 'Competitions',
                        subtitle: 'Battle in elemental arenas',
                        icon: Icons.emoji_events_rounded,
                        color: Colors.amberAccent.shade200.withOpacity(0.9),
                        pillA: 'Open',
                        pillB: 'Ranked',
                        onTap: _goCompetitions,
                        floatPhase: (_floatCtrl.value + 0.66) % 1.0,
                      ),
                    ];

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: isWide
                          ? Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: cards[0]),
                                    const SizedBox(width: 12),
                                    Expanded(child: cards[1]),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                cards[2],
                              ],
                            )
                          : Column(
                              children: [
                                cards[0],
                                const SizedBox(height: 12),
                                cards[1],
                                const SizedBox(height: 12),
                                cards[2],
                              ],
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================
// HEADER (clean, like HomeScreen)
// =============================

class _FieldHeader extends StatelessWidget {
  const _FieldHeader({required this.theme});
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      // visually similar to the simple header rows you use (Avatar row + title)
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // Centered title/subtitle like "ALCHEMONS Research Facility"
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    'FIELD OPERATIONS',
                    style: TextStyle(
                      color: theme.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'Missions • Extraction • Arena',
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================
// ACTION CARD (clean pill/card)
// =============================

class _FieldActionCard extends StatefulWidget {
  const _FieldActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.pillA,
    required this.pillB,
    required this.onTap,
    required this.floatPhase,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String pillA;
  final String pillB;
  final VoidCallback onTap;

  /// A number 0..1 from the parent animation controller so each card can "breathe"
  final double floatPhase;

  @override
  State<_FieldActionCard> createState() => _FieldActionCardState();
}

class _FieldActionCardState extends State<_FieldActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    // gentle vertical float based on provided phase
    final dy = math.sin(widget.floatPhase * 2 * math.pi) * 3.0;
    final scale = _pressed ? 0.98 : 1.0;

    return Transform.translate(
      offset: Offset(0, dy),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          child: GameCard(
            theme: theme,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Subtitle
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MiniPillClean(
                            text: widget.pillA,
                            color: theme.accent,
                            textColor: theme.text,
                          ),
                          _MiniPillClean(
                            text: widget.pillB,
                            color: theme.textMuted.withOpacity(0.18),
                            borderColor: theme.textMuted.withOpacity(0.32),
                            textColor: theme.textMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// circular-ish icon badge, but flattened to match KpiPill chip style
class _IconBadgeClean extends StatelessWidget {
  const _IconBadgeClean({
    required this.icon,
    required this.color,
    required this.bg,
    required this.border,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _MiniPillClean extends StatelessWidget {
  const _MiniPillClean({
    required this.text,
    required this.color,
    required this.textColor,
    this.borderColor,
  });

  final String text;
  final Color color;
  final Color textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor ?? Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
    );
  }
}
