import 'dart:math' show sin;

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/constants/unlock_costs.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/screens/harvest_detail_screen.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/widgets/game_card.dart';

class BiomeHarvestScreen extends StatefulWidget {
  const BiomeHarvestScreen({super.key, this.service});

  final HarvestService? service;

  @override
  State<BiomeHarvestScreen> createState() => _BiomeHarvestScreenState();
}

class _BiomeHarvestScreenState extends State<BiomeHarvestScreen>
    with TickerProviderStateMixin {
  late HarvestService svc;

  @override
  void initState() {
    super.initState();
    svc = widget.service ?? context.read<HarvestService>();
  }

  Future<void> _promptUnlock(BiomeFarmState farm) async {
    final costDb = UnlockCosts.biome(farm.biome);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _UnlockDialog(biome: farm.biome, costDb: costDb),
    );

    if (confirmed == true) {
      final ok = await svc.unlock(farm.biome, cost: costDb);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Unlocked ${farm.biome.label}!' : 'Not enough resources',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.surface,
      body: Stack(
        children: [
          // BIOME BACKGROUND WITH EXTRACTION EQUIPMENT
          Positioned.fill(
            child: ListenableBuilder(
              listenable: svc,
              builder: (_, __) {
                // Show unlocked biomes in background, or all if none unlocked
                final unlockedBiomes = svc.biomes
                    .where((f) => f.unlocked)
                    .map((f) => f.biome)
                    .toList();

                final biomesToShow = unlockedBiomes.isNotEmpty
                    ? unlockedBiomes
                    : svc.biomes.map((f) => f.biome).toList();

                return BiomeExtractionBackground(
                  biomes: biomesToShow,
                  opacity: 0.25, // Adjust this to make more/less subtle
                );
              },
            ),
          ),

          SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: svc,
              builder: (_, __) {
                final biomes = svc.biomes;
                return Column(
                  children: [
                    _HeaderBar(
                      title: 'Biome Extractors',
                      subtitle: 'Extract elemental resources from Alchemons',
                      theme: theme,
                      onBack: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).maybePop();
                      },
                    ),
                    const SizedBox(height: 12),

                    // CONTENT
                    Expanded(
                      child: _BiomeGrid(
                        biomes: biomes,
                        theme: theme,
                        onOpenBiome: (BiomeFarmState f) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BiomeDetailScreen(
                                biome: f.biome,
                                service: svc,
                                discoveredCreatures: [],
                              ),
                            ),
                          );
                        },
                        onUnlockBiome: (BiomeFarmState f) {
                          _promptUnlock(f);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Floating close button at bottom center
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingCloseButton(
                theme: theme,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).maybePop();
                },
                accentColor: theme.text,
                iconColor: theme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// HEADER
// ------------------------------------------------------------

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final FactionTheme theme;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title / subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// BIOME GRID (updated sizing / spacing)
// ------------------------------------------------------------

class _BiomeGrid extends StatelessWidget {
  const _BiomeGrid({
    required this.biomes,
    required this.theme,
    required this.onOpenBiome,
    required this.onUnlockBiome,
  });

  final List<BiomeFarmState> biomes;
  final FactionTheme theme;
  final void Function(BiomeFarmState) onOpenBiome;
  final void Function(BiomeFarmState) onUnlockBiome;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    // Under ~700px -> 1 col list
    // 700px+       -> 2 cols
    final crossAxisCount = w >= 700 ? 2 : 1;

    // We want a short row-ish card, so let height be driven by content.
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // childAspectRatio trick:
        // ~3.2 gives something close to a horizontal tile instead of tall.
        // On 1-col (phone) the tile width is full, so ratio ~3.2 keeps height ~100ish.
        // On 2-col, width ~1/2, so we nudge it down to ~2.8 so it doesn't get too tall.
        childAspectRatio: crossAxisCount == 1 ? 3.2 : 2.8,
      ),
      itemCount: biomes.length,
      itemBuilder: (_, i) {
        final farm = biomes[i];
        return _BiomeCardCompact(
          farm: farm,
          theme: theme,
          onUnlock: () => onUnlockBiome(farm),
          onOpen: () => onOpenBiome(farm),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// BIOME CARD (compact horizontal row version)
// ------------------------------------------------------------

class _BiomeCardCompact extends StatefulWidget {
  const _BiomeCardCompact({
    required this.farm,
    required this.theme,
    required this.onUnlock,
    required this.onOpen,
  });

  final BiomeFarmState farm;
  final FactionTheme theme;
  final VoidCallback onUnlock;
  final VoidCallback onOpen;

  @override
  State<_BiomeCardCompact> createState() => _BiomeCardCompactState();
}

class _BiomeCardCompactState extends State<_BiomeCardCompact> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final biome = widget.farm.biome;
    final accent = widget.farm.currentColor;
    final unlocked = widget.farm.unlocked;
    final hasActive = widget.farm.hasActive;
    final completed = widget.farm.completed;
    final remaining = widget.farm.remaining;

    // status text
    final String statusText = !unlocked
        ? 'LOCKED'
        : (hasActive ? (completed ? '' : 'ACTIVE') : '');

    // compute ETA chip text if extracting
    String? etaText;
    if (hasActive && !completed && remaining != null) {
      final eta = DateTime.now().add(remaining);
      final tod = TimeOfDay.fromDateTime(eta).format(context);
      etaText = 'ETA $tod';
    }

    // tap behavior
    void handleTap() {
      HapticFeedback.lightImpact();
      if (unlocked) {
        widget.onOpen();
      } else {
        widget.onUnlock();
      }
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        handleTap();
      },
      onTapCancel: () => setState(() => _down = false),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onOpen();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _down ? .9 : 1,
        curve: Curves.easeOutCubic,
        child: GameCard(
          theme: widget.theme,
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT COLUMN: icon + main info
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BiomeIconCircleSmall(color: accent, icon: biome.icon),
                    const SizedBox(width: 10),
                    // text stack
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // name row with status chip inline
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  biome.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: widget.theme.text,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: .2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _StatusChipTiny(
                                color: widget.theme.text,
                                text: statusText,
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // description
                          Text(
                            biome.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.theme.textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),

                          const SizedBox(height: 6),

                          // element tags row
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final name in biome.elementTypes)
                                _ElementChipTiny(
                                  label: name,
                                  theme: widget.theme,
                                ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Single status badge
                          if (!unlocked)
                            _TinyInfoPillRow(
                              icon: Icons.lock_outline_rounded,
                              label: 'Requires unlock',
                              theme: widget.theme,
                            )
                          else if (hasActive && !completed && etaText != null)
                            _TinyInfoPillRow(
                              icon: Icons.schedule_rounded,
                              label: etaText,
                              theme: widget.theme,
                            )
                          else if (hasActive && completed)
                            const _TinyReadyPillRow()
                          else
                            _TinyInfoPillRow(
                              icon: Icons.hourglass_empty_rounded,
                              label: 'Idle',
                              theme: widget.theme,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // RIGHT COLUMN: CTA button
              SizedBox(
                width: 50,
                child: _PrimaryActionButtonCompact(
                  theme: widget.theme,
                  accent: accent,
                  label: unlocked ? 'OPEN' : 'UNLOCK',
                  icon: unlocked
                      ? Icons.chevron_right_rounded
                      : Icons.lock_open_rounded,
                  filled: !unlocked, // locked = filled (accent pop)
                  onTap: handleTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// SMALLER SUBCOMPONENTS FOR COMPACT CARD
// ------------------------------------------------------------

class _BiomeIconCircleSmall extends StatelessWidget {
  const _BiomeIconCircleSmall({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(.5), width: 1.2),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

// tinier status chip for inline next to biome name
class _StatusChipTiny extends StatelessWidget {
  const _StatusChipTiny({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = text.toLowerCase();

    late final Color fg;

    switch (t) {
      case 'active':
        fg = Colors.white.withOpacity(.95);
        break;
      default:
        fg = Colors.white.withOpacity(.0);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }
}

// tiny chip for biome.elementNames
class _ElementChipTiny extends StatelessWidget {
  const _ElementChipTiny({required this.label, required this.theme});
  final String label;
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: theme.chipDecoration(rim: theme.accent.withOpacity(0.18)),
      child: Text(
        label,
        style: TextStyle(
          color: theme.text,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

// activity/status mini pills (row form)
class _TinyInfoPillRow extends StatelessWidget {
  const _TinyInfoPillRow({
    required this.icon,
    required this.label,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: theme.chipDecoration(rim: theme.textMuted),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: theme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyReadyPillRow extends StatelessWidget {
  const _TinyReadyPillRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(.5),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ready to extract',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color.fromARGB(255, 255, 255, 255),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

// compact CTA button (sits on right side of row)
class _PrimaryActionButtonCompact extends StatelessWidget {
  const _PrimaryActionButtonCompact({
    required this.theme,
    required this.accent,
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final FactionTheme theme;
  final Color accent;
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? accent.withOpacity(.25) : Colors.white.withOpacity(.03);
    final border = filled
        ? accent.withOpacity(.55)
        : Colors.white.withOpacity(.12);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 15, color: theme.text)],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// UNLOCK DIALOG (CLEANED TO MATCH CARD STYLE, NO GLASS)
// ------------------------------------------------------------

class _UnlockDialog extends StatelessWidget {
  const _UnlockDialog({required this.biome, required this.costDb});

  final Biome biome;
  final Map<String, int> costDb;

  String displayForKey(String k) => ElementResources.byKey[k]?.biomeLabel ?? k;
  IconData iconForKey(String k) =>
      ElementResources.byKey[k]?.icon ?? Icons.blur_on_rounded;

  @override
  Widget build(BuildContext context) {
    final color = biome.primaryColor;
    final db = context.read<AlchemonsDatabase>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withOpacity(.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(.4), width: 1.4),
        ),
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<Map<String, int>>(
          stream: db.currencyDao.watchResourceBalances(),
          builder: (context, snap) {
            final bal = snap.data ?? {};
            bool hasShortage = false;
            for (final e in costDb.entries) {
              final have = bal[e.key] ?? 0;
              if (have < e.value) {
                hasShortage = true;
                break;
              }
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title row
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withOpacity(.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withOpacity(.5),
                          width: 1.4,
                        ),
                      ),
                      child: Icon(biome.icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Unlock ${biome.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE8EAED),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Text(
                  biome.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 14),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Required resources',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.75),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: .2,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                ...costDb.entries.map((e) {
                  final name = displayForKey(e.key);
                  final have = bal[e.key] ?? 0;
                  final need = e.value;
                  final ok = have >= need;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ok
                            ? color.withOpacity(.5)
                            : Colors.redAccent.withOpacity(.5),
                        width: 1.4,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          iconForKey(e.key),
                          size: 16,
                          color: ok ? color : Colors.redAccent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Color(0xFFE8EAED),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: .2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$have / $need',
                          style: TextStyle(
                            color: ok
                                ? Colors.greenAccent.withOpacity(.9)
                                : Colors.redAccent.withOpacity(.9),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _DialogBtn(
                        label: 'Cancel',
                        onTap: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DialogPrimaryBtn(
                        label: hasShortage ? 'Not enough' : 'Confirm Unlock',
                        color: color,
                        disabled: hasShortage,
                        onTap: hasShortage
                            ? null
                            : () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// buttons in dialog (mostly same logic as your originals, minus glow/blur)
class _DialogBtn extends StatelessWidget {
  const _DialogBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      alignment: Alignment.center,
      child: const Text(
        // uppercase in style, like other CTAs
        'CANCEL',
        style: TextStyle(
          color: Color(0xFFE8EAED),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: .5,
        ),
      ),
    ),
  );
}

class _DialogPrimaryBtn extends StatelessWidget {
  const _DialogPrimaryBtn({
    required this.label,
    required this.color,
    required this.disabled,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: disabled ? .5 : 1,
    child: GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(.6), width: 1.4),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: .5,
          ),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------//
/// Animated background for biome extraction screens
/// Shows themed gradient + particle effects for each biome type
class BiomeExtractionBackground extends StatefulWidget {
  const BiomeExtractionBackground({
    super.key,
    required this.biomes,
    this.opacity = 0.3,
  });

  final List<Biome> biomes;
  final double opacity;

  @override
  State<BiomeExtractionBackground> createState() =>
      _BiomeExtractionBackgroundState();
}

class _BiomeExtractionBackgroundState extends State<BiomeExtractionBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    ); // <-- REMOVE .repeat() from here

    // Add this Future.delayed
    Future.delayed(const Duration(milliseconds: 400), () {
      // Check if the widget is still on screen before starting
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient for biome atmosphere
        Positioned.fill(
          child: _BiomeGradientLayer(
            biomes: widget.biomes,
            opacity: widget.opacity,
          ),
        ),

        // Animated particles/elements floating
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _BiomeParticlePainter(
                  biomes: widget.biomes,
                  animation: _controller.value,
                  opacity: widget.opacity * 0.4,
                ),
              );
            },
          ),
        ),

        // Test tube/extraction equipment overlay
        Positioned.fill(
          child: _ExtractionEquipmentOverlay(
            biomes: widget.biomes,
            opacity: widget.opacity * 0.6,
          ),
        ),
      ],
    );
  }
}

/// Gradient layer that blends colors from active biomes
class _BiomeGradientLayer extends StatelessWidget {
  const _BiomeGradientLayer({required this.biomes, required this.opacity});

  final List<Biome> biomes;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    // Get colors from biomes (use first 3 for gradient)
    final colors = biomes.take(3).map((b) => b.primaryColor).toList();

    if (colors.isEmpty) {
      return const SizedBox.shrink();
    }

    // Pad to at least 2 colors for gradient
    while (colors.length < 2) {
      colors.add(colors.first);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[0].withOpacity(opacity),
            if (colors.length > 1) colors[1].withOpacity(opacity * 0.7),
            if (colors.length > 2) colors[2].withOpacity(opacity * 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
      ),
    );
  }
}

/// Floating particle effect painter
class _BiomeParticlePainter extends CustomPainter {
  _BiomeParticlePainter({
    required this.biomes,
    required this.animation,
    required this.opacity,
  });

  final List<Biome> biomes;
  final double animation;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (biomes.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;

    // Generate particles for each biome
    for (
      int biomeIdx = 0;
      biomeIdx < biomes.length && biomeIdx < 3;
      biomeIdx++
    ) {
      final biome = biomes[biomeIdx];
      final color = biome.primaryColor.withOpacity(opacity);
      paint.color = color;

      // Create floating particles with different patterns per biome
      final particleCount = 8 + (biomeIdx * 4);

      for (int i = 0; i < particleCount; i++) {
        final t = (animation + (i / particleCount)) % 1.0;
        final phase = (biomeIdx * 0.3) + (i * 0.1);

        // Position with sine wave motion
        final x = size.width * (0.2 + (0.6 * i / particleCount));
        final y = size.height * t;
        final wobble =
            20 * (1 + biomeIdx) * (0.5 + 0.5 * sin(animation * 2 + phase));

        final offset = Offset(x + wobble, y);

        // Size varies by particle and biome
        final radius =
            (2.0 + biomeIdx * 1.5) * (0.7 + 0.3 * sin(animation * 3 + i));

        canvas.drawCircle(offset, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BiomeParticlePainter oldDelegate) =>
      animation != oldDelegate.animation;
}

/// Test tube and extraction equipment overlay
class _ExtractionEquipmentOverlay extends StatelessWidget {
  const _ExtractionEquipmentOverlay({
    required this.biomes,
    required this.opacity,
  });

  final List<Biome> biomes;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Large test tubes in background (subtle)
        Positioned(
          right: -40,
          top: size.height * 0.15,
          child: Opacity(
            opacity: opacity * 0.3,
            child: _TestTubeShape(
              height: size.height * 0.5,
              width: 80,
              color: biomes.isNotEmpty
                  ? biomes.first.primaryColor
                  : Colors.cyan,
            ),
          ),
        ),

        Positioned(
          left: -30,
          bottom: size.height * 0.1,
          child: Opacity(
            opacity: opacity * 0.25,
            child: _TestTubeShape(
              height: size.height * 0.4,
              width: 70,
              color: biomes.length > 1 ? biomes[1].primaryColor : Colors.green,
            ),
          ),
        ),

        // Extraction grid lines (subtle tech feel)
        Positioned.fill(
          child: Opacity(
            opacity: opacity * 0.15,
            child: CustomPaint(painter: _GridOverlayPainter()),
          ),
        ),
      ],
    );
  }
}

/// Test tube shape widget
class _TestTubeShape extends StatelessWidget {
  const _TestTubeShape({
    required this.height,
    required this.width,
    required this.color,
  });

  final double height;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.3),
            color.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(width * 0.4),
          bottomRight: Radius.circular(width * 0.4),
        ),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
      ),
      child: Stack(
        children: [
          // Liquid level indicator
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: height * 0.6,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withOpacity(0.2), color.withOpacity(0.6)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(width * 0.4),
                  bottomRight: Radius.circular(width * 0.4),
                ),
              ),
            ),
          ),

          // Shine effect
          Positioned(
            left: width * 0.15,
            top: height * 0.1,
            child: Container(
              width: width * 0.2,
              height: height * 0.3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(width * 0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid overlay painter for tech/extraction facility feel
class _GridOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
