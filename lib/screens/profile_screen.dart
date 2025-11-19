// lib/screens/profile_screen.dart
import 'dart:ui';
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
      return const _ProfileData(null, 0);
    }
    final discovered = await svc.discoveredCount();
    return _ProfileData(fid, discovered);
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
    final factionTheme = context.read<FactionTheme>();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ParticleBackgroundScaffold(
      whiteBackground: Theme.of(context).brightness == Brightness.light,
      body: Scaffold(
        backgroundColor: Colors.transparent,
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
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
                    children: [
                      _factionHeader(
                        data.faction!,
                        data.discoveredCount,
                        accent,
                      ),
                      const SizedBox(height: 20),

                      _sectionLabel('GENERAL', accent),
                      const SizedBox(height: 10),
                      _settingTile(
                        title: 'Appearance',
                        trailing: ThemeModeSelector(),
                        accent: accent,
                      ),
                      const SizedBox(height: 10),

                      _settingTile(
                        title: 'Font Style',
                        trailing: _FontSelectorWidget(accent: accent),
                        accent: accent,
                      ),
                      const SizedBox(height: 20),

                      _sectionLabel('DIVISION PERKS', accent),
                      const SizedBox(height: 10),

                      // Show all perks from catalog
                      Builder(
                        builder: (_) {
                          final perks =
                              FactionService.catalog[data.faction!]!.perks;
                          return Column(
                            children: [
                              for (var i = 0; i < perks.length; i++) ...[
                                _perkTile(
                                  title: perks[i].title,
                                  description: perks[i].description,
                                  accent: accent,
                                ),
                                if (i < perks.length - 1)
                                  const SizedBox(height: 10),
                              ],
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),
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
      ),
    );
  }

  // --- helpers ----

  Color _accentFor(FactionId id) {
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
    required Color accent,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final factionTheme = context.read<FactionTheme>();

    return _glassCard(
      borderColor: accent.withOpacity(.45),
      glowColor: accent.withOpacity(.16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
          ],
        ),
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
            color: factionTheme.text,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: .6,
          ),
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
          icon: Icon(Icons.arrow_drop_down, color: factionTheme.text),
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
                style: GoogleFonts.getFont(
                  value,
                  color: factionTheme.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
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
  final int discoveredCount;
  const _ProfileData(this.faction, this.discoveredCount);
}
