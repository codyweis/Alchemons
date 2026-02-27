// lib/screens/profile_screen.dart
//
// REDESIGNED PROFILE / SETTINGS SCREEN
// Aesthetic: Scorched Forge — matches boss_intro_screen / survival_game_screen
// Dark metal panels, amber reagent accents, monospace tactical typography.

import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/story/story_intro_screen.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:alchemons/widgets/theme_switch_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// TYPOGRAPHY HELPERS  (colors resolved at runtime via ForgeTokens)
// ──────────────────────────────────────────────────────────────────────────────

TextStyle _heading(ForgeTokens t) => TextStyle(
  fontFamily: 'monospace',
  color: t.textPrimary,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  letterSpacing: 2.0,
);

TextStyle _label(ForgeTokens t) => TextStyle(
  fontFamily: 'monospace',
  color: t.textSecondary,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.6,
);

TextStyle _body(ForgeTokens t) =>
    TextStyle(color: t.textSecondary, fontSize: 12, height: 1.5);

// ──────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

class _EtchedDivider extends StatelessWidget {
  final String? label;
  const _EtchedDivider({this.label});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: t.borderMid)),
        if (label != null) ...[
          const SizedBox(width: 10),
          Text(label!, style: _label(t)),
          const SizedBox(width: 10),
        ],
        Expanded(child: Container(height: 1, color: t.borderMid)),
      ],
    );
  }
}

/// Flat forge-panel card with optional left accent bar.
class _ForgePanel extends StatelessWidget {
  final Widget child;
  final Color? accentBar;
  final EdgeInsetsGeometry padding;

  const _ForgePanel({
    required this.child,
    this.accentBar,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.borderDim),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accentBar != null)
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accentBar,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
            Expanded(
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact forge action button — matches boss/survival style.
class _ForgeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _ForgeButton({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.bg3,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: isDisabled ? t.borderDim : t.borderAccent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isDisabled ? t.textMuted : t.amber),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: isDisabled ? t.textMuted : t.amberBright,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
// ──────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen(void Function() param0, {super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileData> _load;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<_ProfileData> _fetch() async {
    final svc = context.read<FactionService>();
    final fid = svc.current;
    if (fid == null) return const _ProfileData(null, 0);
    final discovered = await svc.discoveredCount();
    return _ProfileData(fid, discovered);
  }

  Future<void> _replayStory() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StoryIntroScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final factionTheme = context.watch<FactionTheme>();
    final t = ForgeTokens(factionTheme);
    final brightness = Theme.of(context).brightness;

    return ParticleBackgroundScaffold(
      whiteBackground: Theme.of(context).brightness == Brightness.light,
      body: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingCloseButton(
          onTap: () => Navigator.pop(context),
          theme: factionTheme,
        ),
        body: FutureBuilder<_ProfileData>(
          future: _load,
          builder: (context, snap) {
            if (!snap.hasData) {
              return Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.amber,
                  ),
                ),
              );
            }

            final data = snap.data!;
            if (data.faction == null) {
              return Center(
                child: Text(
                  'NO FACTION ASSIGNED',
                  style: _label(t).copyWith(color: t.textMuted),
                ),
              );
            }

            final accentColor = _accentFor(data.faction!, brightness);
            final perks = FactionService.catalog[data.faction!]!.perks;

            return SafeArea(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                children: [
                  // ── Screen title ─────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        color: accentColor,
                        margin: const EdgeInsets.only(right: 10),
                      ),
                      Text('PROFILE', style: _heading(t)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: accentColor.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          data.faction!.name.toUpperCase(),
                          style: _label(t).copyWith(color: accentColor),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Faction header ────────────────────────────────────────
                  _ForgePanel(
                    accentBar: accentColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              size: 14,
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'DIVISION: ${data.faction!.name.toUpperCase()}',
                              style: _heading(t).copyWith(color: accentColor),
                            ),
                          ],
                        ),
                        Container(
                          height: 1,
                          color: t.borderDim,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.catching_pokemon_rounded,
                              size: 12,
                              color: t.teal,
                            ),
                            const SizedBox(width: 6),
                            Text('CREATURES DISCOVERED', style: _label(t)),
                            const Spacer(),
                            Text(
                              '${data.discoveredCount}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.teal,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'GENERAL SETTINGS'),
                  const SizedBox(height: 14),

                  // ── Appearance ────────────────────────────────────────────
                  _ForgePanel(
                    accentBar: t.amber,
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.brightness_4_rounded,
                          size: 14,
                          color: t.amber,
                        ),
                        const SizedBox(width: 8),
                        Text('APPEARANCE', style: _label(t)),
                        const Spacer(),
                        ThemeModeSelector(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Font style ────────────────────────────────────────────
                  _ForgePanel(
                    accentBar: t.amber,
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.text_fields_rounded,
                          size: 14,
                          color: t.amber,
                        ),
                        const SizedBox(width: 8),
                        Text('FONT STYLE', style: _label(t)),
                        const Spacer(),
                        _FontSelectorWidget(t: t),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'DIVISION PERKS'),
                  const SizedBox(height: 14),

                  // ── Perks list ────────────────────────────────────────────
                  for (var i = 0; i < perks.length; i++) ...[
                    _ForgePanel(
                      accentBar: accentColor.withOpacity(0.75),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 12,
                                color: accentColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  perks[i].title.toUpperCase(),
                                  style: _label(t).copyWith(
                                    color: accentColor,
                                    fontSize: 11,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(perks[i].description, style: _body(t)),
                        ],
                      ),
                    ),
                    if (i < perks.length - 1) const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'STORY'),
                  const SizedBox(height: 14),

                  // ── Replay intro ──────────────────────────────────────────
                  _ForgePanel(
                    accentBar: t.teal,
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.movie_filter_rounded,
                          size: 14,
                          color: t.teal,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('REPLAY INTRO', style: _label(t)),
                              const SizedBox(height: 2),
                              Text(
                                'Watch the origin story again',
                                style: _body(t).copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ForgeButton(
                          label: 'WATCH',
                          icon: Icons.play_arrow_rounded,
                          onTap: _replayStory,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _accentFor(FactionId id, Brightness brightness) =>
      factionThemeFor(id, brightness: brightness).accent;
}

// ──────────────────────────────────────────────────────────────────────────────
// FONT SELECTOR
// ──────────────────────────────────────────────────────────────────────────────

class _FontSelectorWidget extends StatelessWidget {
  final ForgeTokens t;
  const _FontSelectorWidget({required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final fontKeys = appFontMap.keys.toList();
    final currentValue = fontKeys.contains(theme.fontName)
        ? theme.fontName
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.borderDim),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          icon: Icon(Icons.arrow_drop_down, color: t.amber, size: 18),
          dropdownColor: t.bg2,
          isDense: true,
          onChanged: (String? newValue) {
            if (newValue != null) {
              context.read<ThemeNotifier>().setFont(newValue);
            }
          },
          items: fontKeys.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: GoogleFonts.getFont(
                  value,
                  color: t.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
          selectedItemBuilder: (context) => fontKeys.map((String value) {
            return Center(
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
// ──────────────────────────────────────────────────────────────────────────────
// DATA
// ──────────────────────────────────────────────────────────────────────────────

class _ProfileData {
  final FactionId? faction;
  final int discoveredCount;
  const _ProfileData(this.faction, this.discoveredCount);
}
