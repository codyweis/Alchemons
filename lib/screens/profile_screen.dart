// lib/screens/profile_screen.dart
import 'dart:ui';
// import 'package:alchemons/screens/faction_picker.dart'; // REMOVED: No longer needed
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/theme_switch_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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
      // If no faction yet, force picker upstream before entering profile.
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
    if (didUnlock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Second perk unlocked!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() => _load = _fetch());
    } else {
      final need = FactionService.perk2DiscoverThreshold;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Discover $need creatures to unlock the second perk.'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final theme = context.read<FactionTheme>();

    return Scaffold(
      body: Stack(
        children: [
          // Content
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
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Choose a faction to begin.',
                        style: TextStyle(
                          color: Color(0xFFE8EAED),
                          fontSize: 14,
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
                  padding: const EdgeInsets.fromLTRB(16, 16 + 8, 16, 24),
                  children: [
                    // MOVED: Faction header is now the first item
                    _factionHeader(data.faction!, data.discoveredCount, accent),
                    const SizedBox(height: 20),

                    // ADDED: General Settings section
                    _sectionLabel('GENERAL', accent),
                    const SizedBox(height: 10),
                    _settingTile(
                      title: 'Appearance',
                      trailing: ThemeModeSelector(),
                      accent: accent,
                    ),
                    const SizedBox(height: 20),

                    // REMOVED: Faction switcher chip
                    // GestureDetector(...)

                    // Section label
                    _sectionLabel('DIVISION PERKS', accent),
                    const SizedBox(height: 10),

                    // Perk 1
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

                    // Perk 2
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
                                  'Requirement: Discover '
                                  '${FactionService.perk2DiscoverThreshold} creatures',
                                )
                              : _activeText(),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Discovery progress mini-card
                    _progressCard(
                      discovered: data.discoveredCount,
                      accent: accent,
                      width: sz.width,
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
    // Reuse global faction palette
    final colors = getFactionColors(id);
    return colors.$1; // primary accent color
  }

  Widget _sectionLabel(String text, Color accent) {
    return Row(
      children: [
        Icon(Icons.dataset_outlined, size: 16, color: accent),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFFE8EAED),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      ],
    );
  }

  Widget _factionHeader(FactionId id, int discovered, Color accent) {
    final (icon, color) = switch (id) {
      FactionId.fire => (Icons.local_fire_department_rounded, Colors.red),
      FactionId.water => (Icons.water_drop_rounded, Colors.blue),
      FactionId.air => (Icons.air_rounded, Colors.cyan),
      FactionId.earth => (Icons.terrain_rounded, Colors.brown),
    };

    final name = id.name[0].toUpperCase() + id.name.substring(1);

    return _glassCard(
      borderColor: accent.withOpacity(.45),
      glowColor: accent.withOpacity(.18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(.35)),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FACTION: $name',
                    style: const TextStyle(
                      color: Color(0xFFE8EAED),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Discovered creatures: $discovered',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _chip(text: 'ACTIVE', color: color.shade400),
          ],
        ),
      ),
    );
  }

  // ADDED: A new generic tile for settings like the theme selector
  Widget _settingTile({
    required String title,
    required Widget trailing,
    required Color accent,
  }) {
    return _glassCard(
      borderColor: Colors.white.withOpacity(.25), // Neutral border
      glowColor: Colors.black.withOpacity(.2), // Neutral glow
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ), // Tighter padding
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: .3,
                  color: Color(0xFFE8EAED),
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
    final statusColor = unlocked ? accent : Colors.white.withOpacity(.35);

    return _glassCard(
      borderColor: statusColor.withOpacity(.45),
      glowColor: unlocked
          ? accent.withOpacity(.16)
          : Colors.black.withOpacity(.2),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: badge + title + action
            Row(
              children: [
                _chip(
                  text: unlocked ? 'UNLOCKED' : 'LOCKED',
                  color: unlocked ? accent : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: .3,
                      color: Color(0xFFE8EAED),
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(.85),
                fontSize: 13,
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

  Widget _reqText(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: Colors.orange.shade200,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _activeText() => Text(
    'Active',
    style: TextStyle(
      fontSize: 12,
      color: Colors.green.shade300,
      fontWeight: FontWeight.w800,
      letterSpacing: .3,
    ),
  );

  Widget _glassButton({
    required String label,
    required VoidCallback onTap,
    required Color accent,
    bool compact = false,
  }) {
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
          border: Border.all(color: Colors.white.withOpacity(.18)),
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: .6,
          ),
        ),
      ),
    );
  }

  Widget _chip({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(.45)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE8EAED),
          fontSize: 10,
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
    // simple soft progress visualization; scale is arbitrary here
    final totalHint = FactionService.perk2DiscoverThreshold;
    final p = (discovered / (totalHint == 0 ? 1 : totalHint)).clamp(0.0, 1.0);

    return _glassCard(
      borderColor: Colors.white.withOpacity(.14),
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
                const Text(
                  'DISCOVERY PROGRESS',
                  style: TextStyle(
                    color: Color(0xFFE8EAED),
                    fontSize: 12,
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
                border: Border.all(color: Colors.white.withOpacity(.14)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: LinearProgressIndicator(
                  value: p,
                  minHeight: 10,
                  backgroundColor: Colors.white.withOpacity(.06),
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
                    style: TextStyle(
                      color: Colors.white.withOpacity(.8),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  'Goal: $totalHint',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (borderColor ?? Colors.white.withOpacity(.14)),
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
