// lib/screens/profile_screen.dart
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/models/faction.dart';
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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<_ProfileData>(
        future: _load,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.faction == null) {
            return const Center(child: Text('Choose a faction to begin.'));
          }

          final perks = FactionService.catalog[data.faction!]!.perks;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _factionHeader(data.faction!, data.discoveredCount),
              const SizedBox(height: 12),

              // Perk 1
              if (perks.isNotEmpty)
                _perkTile(
                  title: perks[0].name,
                  description: perks[0].description,
                  unlocked: data.perk1,
                  badgeColor: Colors.indigo,
                ),
              if (perks.isNotEmpty) const SizedBox(height: 10),

              // Perk 2
              if (perks.length >= 2)
                _perkTile(
                  title: perks[1].name,
                  description: perks[1].description,
                  unlocked: data.perk2,
                  badgeColor: Colors.teal,
                  trailing: !data.perk2
                      ? TextButton(
                          onPressed: _checkUnlockPerk2,
                          child: const Text('Check unlock'),
                        )
                      : null,
                  footer: !data.perk2
                      ? Text(
                          'Requirement: Discover '
                          '${FactionService.perk2DiscoverThreshold} creatures',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        )
                      : const Text('Active', style: TextStyle(fontSize: 12)),
                ),
            ],
          );
        },
      ),
    );
  }

  // --- helpers ----

  Widget _factionHeader(FactionId id, int discovered) {
    final (icon, color) = switch (id) {
      FactionId.fire => (Icons.local_fire_department_rounded, Colors.red),
      FactionId.water => (Icons.water_drop_rounded, Colors.blue),
      FactionId.air => (Icons.air_rounded, Colors.cyan),
      FactionId.earth => (Icons.terrain_rounded, Colors.brown),
    };

    final name = id.name[0].toUpperCase() + id.name.substring(1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Faction: $name',
                  style: TextStyle(
                    color: color.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Discovered creatures: $discovered'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _perkTile({
    required String title,
    required String description,
    required bool unlocked,
    required MaterialColor badgeColor,
    Widget? trailing,
    Widget? footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? badgeColor.shade200 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: unlocked
                      ? badgeColor.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  unlocked ? 'Unlocked' : 'Locked',
                  style: TextStyle(
                    color: unlocked ? badgeColor.shade700 : Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 13)),
          if (footer != null) ...[const SizedBox(height: 6), footer],
        ],
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
