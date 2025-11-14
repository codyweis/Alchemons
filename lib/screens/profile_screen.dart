// lib/screens/profile_screen.dart
import 'dart:ui';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/story/story_intro_screen.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:alchemons/widgets/theme_switch_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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
    if (fid == null) {
      return const _ProfileData(null, false, false, 0);
    }
    await svc.ensureDefaultPerkState(fid);
    final p1 = await svc.isPerkUnlocked(1, forId: fid);
    final p2 = await svc.isPerkUnlocked(2, forId: fid);
    final discovered = await svc.discoveredCount();
    return _ProfileData(fid, p1, p2, discovered);
  }

  Future<void> _checkUnlockPerk2() async {
    final svc = context.read<FactionService>();
    final didUnlock = await svc.tryUnlockPerk2();
    if (!mounted) return;

    final cs = Theme.of(context).colorScheme;

    if (didUnlock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Second perk unlocked!'),
          backgroundColor: cs.secondaryContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: cs.outlineVariant),
          ),
        ),
      );
      setState(() => _load = _fetch());
    } else {
      final need = FactionService.perk2DiscoverThreshold;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Discover $need creatures to unlock the second perk.'),
          backgroundColor: cs.tertiaryContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: cs.outlineVariant),
          ),
        ),
      );
    }
  }

  Future<void> _replayStory() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StoryIntroScreen()),
    );
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final factionTheme = context.read<FactionTheme>(); // you already use this

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingCloseButton(
        onTap: () => Navigator.pop(context),
        theme: factionTheme,
      ),
      body: Stack(
        children: [
          FutureBuilder<_ProfileData>(
            future: _load,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              final data = snap.data!;
              if (data.faction == null) {
                return Center(
                  child: _glassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Choose a faction to begin.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final accent = _accentFor(data.faction!);

              return SafeArea(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    _factionHeader(data.faction!, data.discoveredCount, accent),
                    const SizedBox(height: 20),

                    _sectionLabel('GENERAL', accent),
                    const SizedBox(height: 10),
                    _settingTile(
                      title: 'Appearance',
                      trailing: ThemeModeSelector(),
                      accent: accent,
                    ),
                    const SizedBox(height: 10),

                    // --- 3. ADD THIS SECTION ---
                    _settingTile(
                      title: 'Font Style',
                      trailing: _FontSelectorWidget(
                        accent: accent,
                      ), // New widget
                      accent: accent,
                    ),
                    const SizedBox(height: 20),

                    // --- END NEW SECTION ---
                    _sectionLabel('DIVISION PERKS', accent),
                    const SizedBox(height: 10),

                    Builder(
                      builder: (_) {
                        final perks =
                            FactionService.catalog[data.faction!]!.perks;
                        if (perks.isEmpty) return const SizedBox.shrink();
                        return _perkTile(
                          title: perks[0].name,
                          description: perks[0].description,
                          unlocked: data.perk1,
                          accent: accent,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    Builder(
                      builder: (_) {
                        final perks =
                            FactionService.catalog[data.faction!]!.perks;
                        if (perks.length < 2) return const SizedBox.shrink();
                        return _perkTile(
                          title: perks[1].name,
                          description: perks[1].description,
                          unlocked: data.perk2,
                          accent: accent,
                          trailing: !data.perk2
                              ? _glassButton(
                                  label: 'CHECK UNLOCK',
                                  onTap: _checkUnlockPerk2,
                                  accent: accent,
                                  compact: true,
                                )
                              : null,
                          footer: !data.perk2
                              ? _reqText(
                                  'Requirement: Discover ${FactionService.perk2DiscoverThreshold} creatures',
                                )
                              : _activeText(),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    _progressCard(
                      discovered: data.discoveredCount,
                      accent: accent,
                      width: sz.width,
                    ),
                    const SizedBox(height: 30),
                    _settingTile(
                      title: 'Replay Intro',
                      trailing: _glassButton(
                        label: 'WATCH',
                        onTap: _replayStory,
                        accent: accent,
                        compact: true,
                      ),
                      accent: accent,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- helpers ----

  Color _accentFor(FactionId id) {
    // Keep faction accent, but everything else is theme-driven
    final colors = getFactionColors(id);
    return colors.$1;
  }

  Widget _sectionLabel(String text, Color accent) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(Icons.dataset_outlined, size: 16, color: accent),
        const SizedBox(width: 8),
        Text(
          text,
          style: tt.labelSmall?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      ],
    );
  }

  Widget _factionHeader(FactionId id, int discovered, Color accent) {
    final name = id.name[0].toUpperCase() + id.name.substring(1);
    final factionTheme = context.read<FactionTheme>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return _glassCard(
      borderColor: accent.withOpacity(.45),
      glowColor: accent.withOpacity(.18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FACTION: $name',
                    style: tt.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Discovered creatures: $discovered',
                    style: tt.bodySmall?.copyWith(
                      color: factionTheme.text.withOpacity(.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _chip(text: 'ACTIVE', color: accent),
          ],
        ),
      ),
    );
  }

  Widget _settingTile({
    required String title,
    required Widget trailing,
    required Color accent,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return _glassCard(
      borderColor: cs.outlineVariant,
      glowColor: cs.shadow.withOpacity(.2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .3,
                  color: cs.onSurface,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _perkTile({
    required String title,
    required String description,
    required bool unlocked,
    required Color accent,
    Widget? trailing,
    Widget? footer,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final factionTheme = context.read<FactionTheme>();

    final border = (unlocked ? accent : cs.outlineVariant).withOpacity(.45);
    final glow = unlocked ? accent.withOpacity(.16) : cs.shadow.withOpacity(.2);

    return _glassCard(
      borderColor: border,
      glowColor: glow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _chip(
                  text: unlocked ? 'UNLOCKED' : 'LOCKED',
                  color: unlocked ? accent : cs.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: .3,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: tt.bodyMedium?.copyWith(
                color: factionTheme.text.withOpacity(.85),
                height: 1.28,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (footer != null) ...[const SizedBox(height: 8), footer],
          ],
        ),
      ),
    );
  }

  Widget _reqText(String text) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(
      text,
      style: tt.bodySmall?.copyWith(
        color: cs.tertiary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _activeText() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(
      'Active',
      style: tt.bodySmall?.copyWith(
        color: cs.secondary,
        fontWeight: FontWeight.w800,
        letterSpacing: .3,
      ),
    );
  }

  Widget _glassButton({
    required String label,
    required VoidCallback onTap,
    required Color accent,
    bool compact = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final factionTheme = context.read<FactionTheme>();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          // keep a subtle accent feel, still theme-compliant
          gradient: LinearGradient(
            colors: [accent.withOpacity(.95), accent.withOpacity(.8)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(.25),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: factionTheme.text, // your existing dynamic text color
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: .6,
          ),
        ),
      ),
    );
  }

  Widget _chip({required String text, required Color color}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // draw chip using theme containers for good contrast
    final bg = color.withOpacity(.18);
    final border = color.withOpacity(.45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: tt.labelSmall?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: .5,
        ),
      ),
    );
  }

  Widget _progressCard({
    required int discovered,
    required Color accent,
    required double width,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final totalHint = FactionService.perk2DiscoverThreshold;
    final p = (discovered / (totalHint == 0 ? 1 : totalHint)).clamp(0.0, 1.0);

    return _glassCard(
      borderColor: cs.outlineVariant,
      glowColor: accent.withOpacity(.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 16, color: accent),
                const SizedBox(width: 8),
                Text(
                  'DISCOVERY PROGRESS',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: LinearProgressIndicator(
                  value: p,
                  minHeight: 10,
                  backgroundColor: cs.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$discovered discovered',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(.8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Goal: $totalHint',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    Color? borderColor,
    Color? glowColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (borderColor ?? cs.outlineVariant),
              width: 2,
            ),
            boxShadow: glowColor == null
                ? null
                : [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FontSelectorWidget extends StatelessWidget {
  final Color accent;
  const _FontSelectorWidget({required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final cs = Theme.of(context).colorScheme;
    final factionTheme = context.read<FactionTheme>();

    // We reuse the styling from your _glassButton
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(.95), accent.withOpacity(.8)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(.25),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: theme.fontName,
          // Use the accent color for the icon
          icon: Icon(Icons.arrow_drop_down, color: factionTheme.text),
          // Make the dropdown menu match your "glass" theme
          dropdownColor: cs.surface.withOpacity(0.95),
          isDense: true,
          onChanged: (String? newValue) {
            if (newValue != null) {
              context.read<ThemeNotifier>().setFont(newValue);
            }
          },
          items: appFontMap.keys.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                // Use the font itself for the preview in the list
                style: GoogleFonts.getFont(
                  value,
                  color: factionTheme.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
          // Style the selected value in the button
          selectedItemBuilder: (context) {
            return appFontMap.keys.map((String value) {
              return Center(
                child: Text(
                  value,
                  style: TextStyle(
                    color: factionTheme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: .6,
                  ),
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}

class _ProfileData {
  final FactionId? faction;
  final bool perk1;
  final bool perk2;
  final int discoveredCount;
  const _ProfileData(
    this.faction,
    this.perk1,
    this.perk2,
    this.discoveredCount,
  );
}
