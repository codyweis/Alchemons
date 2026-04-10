import 'package:flutter/material.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'cosmic_screen_styles.dart';

String _fmt(num n) {
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i] != '-') buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class HomePlanetMenuOverlay extends StatelessWidget {
  const HomePlanetMenuOverlay({
    super.key,
    required this.homePlanet,
    required this.elementStorage,
    required this.onCustomize,
    required this.onGarrison,
    required this.onClose,
  });

  final HomePlanet homePlanet;
  final ElementStorage elementStorage;
  final VoidCallback onCustomize;
  final VoidCallback onGarrison;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final col = homePlanet.blendedColor;
    final totalDeposited = homePlanet.colorMix.values.fold(
      0.0,
      (s, v) => s + v,
    );
    final sortedMix = homePlanet.colorMix.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final storageEntries =
        elementStorage.stored.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: Container(
          color: CosmicScreenStyles.bg0.withValues(alpha: 0.92),
          child: SafeArea(
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 20,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: CosmicScreenStyles.bg1,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: CosmicScreenStyles.borderDim),
                      boxShadow: [
                        BoxShadow(
                          color: col.withValues(alpha: 0.10),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Corner notches
                        Positioned(
                          top: 0,
                          left: 0,
                          child: _cornerNotch(col, topLeft: true),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: _cornerNotch(col, topLeft: false),
                        ),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Header with planet orb ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Color.lerp(col, Colors.white, 0.3)!,
                                        col,
                                        Color.lerp(col, Colors.black, 0.4)!,
                                      ],
                                      stops: const [0.0, 0.55, 1.0],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: col.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'HOME BASE',
                                  style: TextStyle(
                                    fontFamily: appFontFamily(context),
                                    color: CosmicScreenStyles.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _etchedDivider(col),
                            const SizedBox(height: 16),

                            const SizedBox(height: 12),

                            // ── Planet Composition ──
                            _forgeSection(
                              context,
                              'PLANET',
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: col,
                                          boxShadow: [
                                            BoxShadow(
                                              color: col.withValues(alpha: 0.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_fmt(totalDeposited)} ELEMENTS',
                                        style: TextStyle(
                                          fontFamily: appFontFamily(context),
                                          color:
                                              CosmicScreenStyles.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (sortedMix.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(1),
                                        border: Border.all(
                                          color: CosmicScreenStyles.borderDim,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(1),
                                        child: Row(
                                          children: sortedMix.take(7).map((e) {
                                            final pct = totalDeposited > 0
                                                ? e.value / totalDeposited
                                                : 0.0;
                                            return Expanded(
                                              flex: (pct * 100).round().clamp(
                                                1,
                                                100,
                                              ),
                                              child: Container(
                                                color: elementColor(e.key),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (sortedMix.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Deposit elements to change your planet color.',
                                        style: TextStyle(
                                          fontFamily: appFontFamily(context),
                                          color: CosmicScreenStyles.textMuted,
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              accent: col,
                            ),
                            const SizedBox(height: 12),

                            // ── Element Storage ──
                            _forgeSection(
                              context,
                              'ELEMENT STORAGE',
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (storageEntries.isEmpty)
                                    Text(
                                      'No elements stored yet.',
                                      style: TextStyle(
                                        fontFamily: appFontFamily(context),
                                        color: CosmicScreenStyles.textMuted,
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: storageEntries.take(12).map((
                                        e,
                                      ) {
                                        final ec = elementColor(e.key);
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: ec.withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                            border: Border.all(
                                              color: ec.withValues(alpha: 0.40),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            '${e.key} ${_fmt(e.value)}',
                                            style: TextStyle(
                                              fontFamily: appFontFamily(context),
                                              color: ec,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                              accent: CosmicScreenStyles.teal,
                            ),
                            const SizedBox(height: 16),

                            // ── Actions ──
                            _forgeSection(
                              context,
                              'ACTIONS',
                              Column(
                                children: [
                                  _homeAction(
                                    context: context,
                                    icon: Icons.auto_awesome,
                                    label: 'CUSTOMIZE',
                                    onTap: onCustomize,
                                    primary: true,
                                  ),
                                  const SizedBox(height: 8),
                                  _homeAction(
                                    context: context,
                                    icon: Icons.shield,
                                    label: 'GARRISON',
                                    onTap: onGarrison,
                                  ),
                                ],
                              ),
                              accent: CosmicScreenStyles.amberBright,
                            ),
                            const SizedBox(height: 16),

                            // ── Close ──
                            GestureDetector(
                              onTap: onClose,
                              child: Container(
                                width: double.infinity,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: CosmicScreenStyles.borderAccent
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'CLOSE',
                                  style: TextStyle(
                                    fontFamily: appFontFamily(context),
                                    color: CosmicScreenStyles.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Forge section with header bar ──
  Widget _forgeSection(
    BuildContext context,
    String title,
    Widget child, {
    Color? accent,
  }) {
    final a = accent ?? CosmicScreenStyles.amber;
    return Container(
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: CosmicScreenStyles.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: CosmicScreenStyles.bg3,
              borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
              border: Border(
                bottom: BorderSide(color: CosmicScreenStyles.borderDim),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 10,
                  color: a,
                  margin: const EdgeInsets.only(right: 8),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: a,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  // ── Forge action button ──
  Widget _homeAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: primary ? 46 : 40,
        decoration: BoxDecoration(
          color: primary ? CosmicScreenStyles.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: primary
                ? CosmicScreenStyles.amberGlow
                : CosmicScreenStyles.borderAccent.withValues(alpha: 0.6),
            width: primary ? 1 : 0.8,
          ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: CosmicScreenStyles.amber.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: primary
                  ? CosmicScreenStyles.bg0
                  : CosmicScreenStyles.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: primary
                    ? CosmicScreenStyles.bg0
                    : CosmicScreenStyles.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Etched divider with center dot ──
  static Widget _etchedDivider(Color accent) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: CosmicScreenStyles.borderMid),
        ),
        const SizedBox(width: 6),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(height: 1, color: CosmicScreenStyles.borderMid),
        ),
      ],
    );
  }

  // ── Corner notch decoration ──
  static Widget _cornerNotch(Color accent, {required bool topLeft}) {
    final border = topLeft
        ? Border(
            top: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
            left: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
          )
        : Border(
            bottom: BorderSide(
              color: accent.withValues(alpha: 0.5),
              width: 1.5,
            ),
            right: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
          );
    return SizedBox(
      width: 10,
      height: 10,
      child: DecoratedBox(decoration: BoxDecoration(border: border)),
    );
  }
}

// ─────────────────────────────────────────────────────────
// CHAMBER PICKER OVERLAY (assign Alchemons to orbital slots)
// With instance-sheet-style filtering, search, and sort.
// ─────────────────────────────────────────────────────────
