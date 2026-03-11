// lib/screens/profile_screen.dart
//
// REDESIGNED PROFILE / SETTINGS SCREEN
// Aesthetic: Scorched Forge — matches boss_intro_screen / survival_game_screen
// Dark metal panels, amber reagent accents, monospace tactical typography.

import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/screens/story/story_intro_screen.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/notification_preferences_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:alchemons/widgets/theme_switch_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
            color: Colors.black.withValues(alpha: 0.35),
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
  final NotificationPreferencesService _notificationPrefs =
      NotificationPreferencesService();
  final CinematicQualityService _cinematicQualityService =
      CinematicQualityService();
  final PushNotificationService _pushNotifications = PushNotificationService();
  bool _cultivationsEnabled = true;
  bool _wildernessEnabled = true;
  bool _extractionsEnabled = true;
  bool _notificationPrefsLoaded = false;
  CinematicQuality _cinematicQuality = CinematicQuality.high;
  bool _cinematicQualityLoaded = false;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
    _loadNotificationPrefs();
    _loadCinematicQuality();
  }

  Future<_ProfileData> _fetch() async {
    final svc = context.read<FactionService>();
    final fid = svc.current;
    final prefs = await SharedPreferences.getInstance();
    final noteIds = deserialiseContestHintIds(
      prefs.getString('cosmic_trait_hint_notes_v1') ?? '',
    );
    final cosmicHints = kCosmicContestHintLore
        .where((h) => noteIds.contains(h.id))
        .toList();

    if (fid == null) return _ProfileData(null, 0, cosmicHints);
    final discovered = await svc.discoveredCount();
    return _ProfileData(fid, discovered, cosmicHints);
  }

  Future<void> _replayStory() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StoryIntroScreen()),
    );
  }

  Future<void> _openEncyclopedia() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AlchemicalEncyclopediaScreen()),
    );
  }

  Future<void> _loadNotificationPrefs() async {
    final cultivations = await _notificationPrefs.isCultivationsEnabled();
    final wilderness = await _notificationPrefs.isWildernessEnabled();
    final extractions = await _notificationPrefs.isExtractionsEnabled();
    if (!mounted) return;
    setState(() {
      _cultivationsEnabled = cultivations;
      _wildernessEnabled = wilderness;
      _extractionsEnabled = extractions;
      _notificationPrefsLoaded = true;
    });
  }

  Future<void> _toggleCultivations(bool value) async {
    setState(() => _cultivationsEnabled = value);
    await _notificationPrefs.setCultivationsEnabled(value);
    if (!value) {
      await _pushNotifications.cancelEggNotification();
    }
  }

  Future<void> _toggleWilderness(bool value) async {
    setState(() => _wildernessEnabled = value);
    await _notificationPrefs.setWildernessEnabled(value);
    if (!value) {
      await _pushNotifications.cancelWildernessNotifications();
    }
  }

  Future<void> _toggleExtractions(bool value) async {
    setState(() => _extractionsEnabled = value);
    await _notificationPrefs.setExtractionsEnabled(value);
    if (!value) {
      await _pushNotifications.cancelHarvestNotification();
    }
  }

  Future<void> _loadCinematicQuality() async {
    final quality = await _cinematicQualityService.getQuality();
    if (!mounted) return;
    setState(() {
      _cinematicQuality = quality;
      _cinematicQualityLoaded = true;
    });
  }

  Future<void> _setCinematicQuality(CinematicQuality value) async {
    setState(() => _cinematicQuality = value);
    await _cinematicQualityService.setQuality(value);
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
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          data.faction!.name.toUpperCase(),
                          style: _label(t).copyWith(color: accentColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _openEncyclopedia,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: t.borderDim),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 22,
                            color: t.textSecondary,
                          ),
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
                  const _EtchedDivider(label: 'COSMIC NOTES'),
                  const SizedBox(height: 14),

                  _ForgePanel(
                    accentBar: t.teal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 14,
                              color: t.teal,
                            ),
                            const SizedBox(width: 8),
                            Text('DISCOVERED HINT NOTES', style: _label(t)),
                            const Spacer(),
                            Text(
                              '${data.cosmicHints.length}',
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
                        const SizedBox(height: 8),
                        if (data.cosmicHints.isEmpty)
                          Text(
                            'No cosmic hint notes discovered yet.',
                            style: _body(t).copyWith(fontSize: 11),
                          )
                        else ...[
                          for (final hint in data.cosmicHints.take(6))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '• ${hint.text}',
                                style: _body(t).copyWith(fontSize: 11),
                              ),
                            ),
                          if (data.cosmicHints.length > 6)
                            Text(
                              '+${data.cosmicHints.length - 6} more archived notes',
                              style: _body(
                                t,
                              ).copyWith(fontSize: 10, color: t.textMuted),
                            ),
                        ],
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

                  const SizedBox(height: 10),

                  _ForgePanel(
                    accentBar: t.amber,
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.movie_filter_rounded,
                          size: 14,
                          color: t.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CINEMATIC QUALITY', style: _label(t)),
                              const SizedBox(height: 2),
                              Text(
                                'Extraction and hatch visual intensity',
                                style: _body(t).copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _CinematicQualitySelector(
                          t: t,
                          value: _cinematicQuality,
                          enabled: _cinematicQualityLoaded,
                          onChanged: _setCinematicQuality,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'NOTIFICATIONS'),
                  const SizedBox(height: 14),

                  _ForgePanel(
                    accentBar: t.teal,
                    child: Column(
                      children: [
                        _NotificationToggleRow(
                          icon: Icons.science_rounded,
                          title: 'CULTIVATIONS',
                          subtitle: 'Egg ready and extraction-ready alerts',
                          value: _cultivationsEnabled,
                          enabled: _notificationPrefsLoaded,
                          onChanged: _toggleCultivations,
                          accent: t.teal,
                        ),
                        const SizedBox(height: 8),
                        _NotificationToggleRow(
                          icon: Icons.explore_rounded,
                          title: 'WILDERNESS',
                          subtitle: 'Wild spawn alerts across biomes',
                          value: _wildernessEnabled,
                          enabled: _notificationPrefsLoaded,
                          onChanged: _toggleWilderness,
                          accent: t.teal,
                        ),
                        const SizedBox(height: 8),
                        _NotificationToggleRow(
                          icon: Icons.science_outlined,
                          title: 'EXTRACTIONS',
                          subtitle: 'Biome harvest completion alerts',
                          value: _extractionsEnabled,
                          enabled: _notificationPrefsLoaded,
                          onChanged: _toggleExtractions,
                          accent: t.teal,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'DIVISION PERKS'),
                  const SizedBox(height: 14),

                  // ── Perks list ────────────────────────────────────────────
                  for (var i = 0; i < perks.length; i++) ...[
                    _ForgePanel(
                      accentBar: accentColor.withValues(alpha: 0.75),
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

class _CinematicQualitySelector extends StatelessWidget {
  final ForgeTokens t;
  final CinematicQuality value;
  final bool enabled;
  final Future<void> Function(CinematicQuality value) onChanged;

  const _CinematicQualitySelector({
    required this.t,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  String _labelFor(CinematicQuality quality) {
    return switch (quality) {
      CinematicQuality.high => 'HIGH',
      CinematicQuality.balanced => 'BALANCED',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: t.bg3,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: t.borderDim),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<CinematicQuality>(
            value: value,
            icon: Icon(Icons.arrow_drop_down, color: t.amber, size: 18),
            dropdownColor: t.bg2,
            isDense: true,
            onChanged: enabled
                ? (next) {
                    if (next == null) return;
                    HapticFeedback.selectionClick();
                    onChanged(next);
                  }
                : null,
            items: CinematicQuality.values
                .map(
                  (q) => DropdownMenuItem<CinematicQuality>(
                    value: q,
                    child: Text(
                      _labelFor(q),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final Future<void> Function(bool value) onChanged;
  final Color accent;

  const _NotificationToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Row(
      children: [
        Icon(icon, size: 14, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _label(t)),
              const SizedBox(height: 2),
              Text(subtitle, style: _body(t).copyWith(fontSize: 10)),
            ],
          ),
        ),
        IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: Switch.adaptive(
              value: value,
              activeColor: accent,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
// ──────────────────────────────────────────────────────────────────────────────
// DATA
// ──────────────────────────────────────────────────────────────────────────────

class _ProfileData {
  final FactionId? faction;
  final int discoveredCount;
  final List<CosmicContestHintLore> cosmicHints;
  const _ProfileData(this.faction, this.discoveredCount, this.cosmicHints);
}
