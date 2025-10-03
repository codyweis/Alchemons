import 'dart:convert';
import 'dart:ui';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/alchemons_db.dart';
import '../widgets/stamina_bar.dart';
import '../providers/app_providers.dart';

class PartyPickerPage extends StatefulWidget {
  const PartyPickerPage({super.key});

  @override
  State<PartyPickerPage> createState() => _PartyPickerPageState();
}

class _PartyPickerPageState extends State<PartyPickerPage>
    with SingleTickerProviderStateMixin {
  String? _selectedSpeciesId;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final (primaryColor, _, accentColor) = getFactionColors(currentFaction);
    final db = context.watch<AlchemonsDatabase>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0B0F14).withOpacity(0.96),
              const Color(0xFF0B0F14).withOpacity(0.92),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(accentColor),
              _buildTeamStatus(accentColor),
              if (_selectedSpeciesId != null)
                _buildSelectedSpeciesBanner(accentColor),
              Expanded(
                child: StreamBuilder<List<CreatureInstance>>(
                  stream: db.watchAllInstances(),
                  builder: (_, snap) {
                    final instances = snap.data ?? const <CreatureInstance>[];
                    return _buildMainContent(instances, accentColor);
                  },
                ),
              ),
              _PartyFooter(accentColor: accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: _GlassContainer(
        accentColor: accentColor,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _IconButton(
                icon: Icons.arrow_back_rounded,
                accentColor: accentColor,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TEAM ASSEMBLY', style: _TextStyles.headerTitle),
                    const SizedBox(height: 2),
                    Text(
                      'Select up to 3 specimens for deployment',
                      style: _TextStyles.headerSubtitle,
                    ),
                  ],
                ),
              ),
              _GlowingIcon(
                icon: Icons.groups_rounded,
                color: accentColor,
                controller: _glowController,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamStatus(Color accentColor) {
    final party = context.watch<SelectedPartyNotifier>();
    final count = party.members.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: StreamBuilder<List<CreatureInstance>>(
        stream: context.watch<AlchemonsDatabase>().watchAllInstances(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _LoadingTeamStatus(accentColor: accentColor);
          }

          final allInstances = snapshot.data!;
          final selectedInstances = party.members
              .map(
                (m) => allInstances.firstWhere(
                  (inst) => inst.instanceId == m.instanceId,
                  orElse: () => null as CreatureInstance,
                ),
              )
              .whereType<CreatureInstance>()
              .toList();

          return _GlassContainer(
            accentColor: count > 0 ? Colors.green.shade400 : accentColor,
            glowController: _glowController,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        color: count > 0
                            ? Colors.green.shade400
                            : _TextStyles.mutedText,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        count > 0 ? 'Current Team' : 'No Team Selected',
                        style: _TextStyles.labelText,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (count > 0
                                      ? Colors.green.shade400
                                      : Colors.grey.shade600)
                                  .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                (count > 0
                                        ? Colors.green.shade400
                                        : Colors.grey.shade600)
                                    .withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          '$count / ${SelectedPartyNotifier.maxSize}',
                          style: TextStyle(
                            color: count > 0
                                ? Colors.green.shade400
                                : Colors.grey.shade500,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(SelectedPartyNotifier.maxSize, (i) {
                      if (i > 0) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: i < selectedInstances.length
                                ? _TeamSlotFilled(
                                    instance: selectedInstances[i],
                                    onRemove: () => context
                                        .read<SelectedPartyNotifier>()
                                        .toggle(
                                          selectedInstances[i].instanceId,
                                        ),
                                  )
                                : _TeamSlotEmpty(),
                          ),
                        );
                      }
                      return Expanded(
                        child: i < selectedInstances.length
                            ? _TeamSlotFilled(
                                instance: selectedInstances[i],
                                onRemove: () => context
                                    .read<SelectedPartyNotifier>()
                                    .toggle(selectedInstances[i].instanceId),
                              )
                            : _TeamSlotEmpty(),
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedSpeciesBanner(Color accentColor) {
    final gameState = context.watch<GameStateNotifier>();
    final speciesData = gameState.discoveredCreatures.firstWhere(
      (data) => (data['creature'] as Creature).id == _selectedSpeciesId,
      orElse: () => <String, Object>{},
    );

    if (speciesData.isEmpty) return const SizedBox.shrink();

    final creature = speciesData['creature'] as Creature;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: _GlassContainer(
        accentColor: Colors.blue.shade400,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: CreatureFilterUtils.getTypeColor(
                      creature.types.first,
                    ),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: creature.spriteData != null
                      ? Image.asset('assets/images/${creature.image}')
                      : Icon(
                          CreatureFilterUtils.getTypeIcon(creature.types.first),
                          size: 16,
                          color: CreatureFilterUtils.getTypeColor(
                            creature.types.first,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(creature.name, style: _TextStyles.cardTitle),
                    Text('Select instances', style: _TextStyles.hint),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedSpeciesId = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade400.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.orange.shade400.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.orange.shade400,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Change',
                        style: TextStyle(
                          color: Colors.orange.shade400,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    List<CreatureInstance> instances,
    Color accentColor,
  ) {
    if (_selectedSpeciesId == null) {
      return _buildSpeciesGrid(accentColor);
    } else {
      return _buildInstanceGrid(instances, accentColor);
    }
  }

  Widget _buildSpeciesGrid(Color accentColor) {
    final gameState = context.watch<GameStateNotifier>();
    final species = gameState.discoveredCreatures;

    if (species.isEmpty) {
      return _EmptyState(message: 'No specimens discovered');
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Icon(Icons.science_rounded, color: accentColor, size: 16),
                const SizedBox(width: 6),
                Text('Select Species', style: _TextStyles.sectionTitle),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.9,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: species.length,
              itemBuilder: (_, i) => _SpeciesCard(
                creature: species[i]['creature'] as Creature,
                glowController: _glowController,
                onTap: () => setState(
                  () => _selectedSpeciesId =
                      (species[i]['creature'] as Creature).id,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstanceGrid(
    List<CreatureInstance> allInstances,
    Color accentColor,
  ) {
    final filtered = allInstances
        .where((inst) => inst.baseId == _selectedSpeciesId)
        .toList();

    if (filtered.isEmpty) {
      return _EmptyState(message: 'No instances found for this species');
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Icon(Icons.pets_rounded, color: accentColor, size: 16),
                const SizedBox(width: 6),
                Text('Select Team Members', style: _TextStyles.sectionTitle),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    '${filtered.length} available',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final instance = filtered[i];
                final party = context.watch<SelectedPartyNotifier>();
                final selected = party.contains(instance.instanceId);
                final disabled = instance.locked;

                return _InstanceCard(
                  instance: instance,
                  selected: selected,
                  disabled: disabled,
                  glowController: _glowController,
                  onTap: disabled
                      ? null
                      : () => context.read<SelectedPartyNotifier>().toggle(
                          instance.instanceId,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== REUSABLE COMPONENTS ====================

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final AnimationController glowController;

  const _GlassContainer({
    required this.child,
    required this.accentColor,
    required this.glowController,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedBuilder(
          animation: glowController,
          builder: (context, _) {
            final glow = 0.35 + glowController.value * 0.4;
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(glow * 0.85)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(glow * 0.5),
                    blurRadius: 20 + glowController.value * 14,
                  ),
                ],
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withOpacity(.35)),
        ),
        child: Icon(icon, color: _TextStyles.softText, size: 18),
      ),
    );
  }
}

class _GlowingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final AnimationController controller;

  const _GlowingIcon({
    required this.icon,
    required this.color,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final glow = 0.35 + controller.value * 0.4;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(.3), Colors.transparent],
            ),
            border: Border.all(color: color.withOpacity(glow)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(glow * .4),
                blurRadius: 20 + controller.value * 14,
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: color),
        );
      },
    );
  }
}

class _LoadingTeamStatus extends StatelessWidget {
  final Color accentColor;

  const _LoadingTeamStatus({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(accentColor),
            ),
          ),
          const SizedBox(width: 12),
          Text('Loading team data...', style: _TextStyles.hint),
        ],
      ),
    );
  }
}

class _TeamSlotFilled extends StatelessWidget {
  final CreatureInstance instance;
  final VoidCallback onRemove;

  const _TeamSlotFilled({required this.instance, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CreatureRepository>();
    final base = repo.getCreatureById(instance.baseId);
    final name = base?.name ?? instance.baseId;

    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.green.shade400.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: base != null
                ? CreatureFilterUtils.getTypeColor(
                    base.types.first,
                  ).withOpacity(0.6)
                : Colors.grey.shade600,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: base != null
                      ? CreatureFilterUtils.getTypeColor(base.types.first)
                      : Colors.grey.shade400,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: base?.spriteData != null
                    ? Image.asset(
                        'assets/images/${base!.image}',
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        base != null
                            ? CreatureFilterUtils.getTypeIcon(base.types.first)
                            : Icons.help_outline,
                        size: 14,
                        color: base != null
                            ? CreatureFilterUtils.getTypeColor(base.types.first)
                            : Colors.grey.shade600,
                      ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              name,
              style: TextStyle(
                color: Colors.green.shade400,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'L${instance.level}',
              style: TextStyle(
                color: Colors.amber.shade400,
                fontSize: 7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSlotEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                style: BorderStyle.solid,
              ),
            ),
            child: Icon(
              Icons.add_outlined,
              size: 14,
              color: _TextStyles.mutedText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Empty',
            style: TextStyle(
              color: _TextStyles.mutedText,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '--',
            style: TextStyle(
              color: _TextStyles.mutedText,
              fontSize: 7,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  final Creature creature;
  final AnimationController glowController;
  final VoidCallback onTap;

  const _SpeciesCard({
    required this.creature,
    required this.glowController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = CreatureFilterUtils.getTypeColor(creature.types.first);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedBuilder(
            animation: glowController,
            builder: (context, _) {
              final glow = 0.35 + glowController.value * 0.4;
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: typeColor.withOpacity(glow * 0.85),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: typeColor.withOpacity(glow * 0.5),
                      blurRadius: 20 + glowController.value * 14,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: typeColor, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: creature.spriteData != null
                              ? Image.asset('assets/images/${creature.image}')
                              : Icon(
                                  CreatureFilterUtils.getTypeIcon(
                                    creature.types.first,
                                  ),
                                  size: 32,
                                  color: typeColor,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      creature.name,
                      style: _TextStyles.cardSmallTitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InstanceCard extends StatelessWidget {
  final CreatureInstance instance;
  final bool selected;
  final bool disabled;
  final AnimationController glowController;
  final VoidCallback? onTap;

  const _InstanceCard({
    required this.instance,
    required this.selected,
    required this.disabled,
    required this.glowController,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CreatureRepository>();
    final hydrated = _CreatureHelper.hydrateCreature(repo, instance);
    final base = repo.getCreatureById(instance.baseId);
    final name = instance.nickname?.isNotEmpty == true
        ? instance.nickname!
        : base?.name ?? instance.baseId;
    final genetics = _CreatureHelper.parseGenetics(instance);

    final borderColor = selected
        ? Colors.green.shade400
        : disabled
        ? Colors.grey.shade600
        : base != null
        ? CreatureFilterUtils.getTypeColor(base.types.first)
        : Colors.grey.shade600;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedBuilder(
            animation: glowController,
            builder: (context, _) {
              final glow = selected ? 0.35 + glowController.value * 0.4 : 0.2;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(
                    selected ? 0.12 : (disabled ? 0.25 : 0.14),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor.withOpacity(glow * 0.85),
                    width: selected ? 2 : 1.5,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: borderColor.withOpacity(glow * 0.5),
                            blurRadius: 20 + glowController.value * 14,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    // Creature sprite
                    SizedBox(
                      height: 100,
                      width: 100,
                      child: _CreatureDisplay(
                        hydrated: hydrated,
                        fallbackColor: borderColor,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Name
                    Text(
                      name,
                      style: disabled
                          ? _TextStyles.cardTitleDisabled
                          : _TextStyles.cardTitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Stamina
                    _UniformBadge(
                      color: Colors.green,
                      child: StaminaBadge(
                        instanceId: instance.instanceId,
                        showCountdown: true,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Level and XP
                    Row(
                      children: [
                        Expanded(
                          child: _UniformBadge(
                            color: Colors.amber,
                            child: Text(
                              'L${instance.level}',
                              style: TextStyle(
                                color: Colors.amber.shade400,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _UniformBadge(
                            color: Colors.green,
                            child: Text(
                              '${instance.xp}XP',
                              style: TextStyle(
                                color: Colors.green.shade400,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Nature
                    _UniformBadge(
                      color: instance.natureId != null
                          ? Colors.purple
                          : Colors.grey,
                      child: Text(
                        instance.natureId ?? 'None',
                        style: TextStyle(
                          color: instance.natureId != null
                              ? Colors.purple.shade400
                              : Colors.grey.shade500,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Genetics badges
                    if (genetics != null) ..._buildGeneticsBadges(genetics),

                    // Prismatic
                    if (instance.isPrismaticSkin) ...[
                      const SizedBox(height: 4),
                      _UniformBadge(
                        color: Colors.pink,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Text(
                              'Prismatic',
                              style: TextStyle(
                                color: Colors.pink.shade400,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGeneticsBadges(Map<String, String> genetics) {
    final badges = <Widget>[];
    final size = genetics['size'];
    final tint = genetics['tinting'];

    if (size != null && size != 'normal') {
      badges.add(const SizedBox(height: 4));
      badges.add(
        _UniformBadge(
          color: _getGeneticsColor(size, true),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getSizeIcon(size),
                size: 12,
                color: _getGeneticsTextColor(size, true),
              ),
              const SizedBox(width: 4),
              Text(
                _getSizeLabel(size),
                style: TextStyle(
                  color: _getGeneticsTextColor(size, true),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (tint != null && tint != 'normal') {
      badges.add(const SizedBox(height: 4));
      badges.add(
        _UniformBadge(
          color: _getGeneticsColor(tint, false),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getTintIcon(tint),
                size: 12,
                color: _getGeneticsTextColor(tint, false),
              ),
              const SizedBox(width: 4),
              Text(
                _getTintLabel(tint),
                style: TextStyle(
                  color: _getGeneticsTextColor(tint, false),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return badges;
  }

  MaterialColor _getGeneticsColor(String variant, bool isSize) {
    if (isSize) {
      switch (variant) {
        case 'tiny':
          return Colors.pink;
        case 'small':
          return Colors.blue;
        case 'large':
          return Colors.green;
        case 'giant':
          return Colors.orange;
        default:
          return Colors.grey;
      }
    } else {
      switch (variant) {
        case 'warm':
          return Colors.red;
        case 'cool':
          return Colors.cyan;
        case 'vibrant':
          return Colors.purple;
        case 'pale':
          return Colors.grey;
        default:
          return Colors.grey;
      }
    }
  }

  Color _getGeneticsTextColor(String variant, bool isSize) {
    return _getGeneticsColor(variant, isSize).shade400;
  }

  IconData _getSizeIcon(String size) {
    switch (size) {
      case 'tiny':
        return Icons.radio_button_unchecked;
      case 'small':
        return Icons.remove_circle_outline;
      case 'large':
        return Icons.add_circle_outline;
      case 'giant':
        return Icons.circle_outlined;
      default:
        return Icons.circle;
    }
  }

  String _getSizeLabel(String size) {
    switch (size) {
      case 'tiny':
        return 'Tiny';
      case 'small':
        return 'Small';
      case 'large':
        return 'Large';
      case 'giant':
        return 'Giant';
      default:
        return size;
    }
  }

  IconData _getTintIcon(String tint) {
    switch (tint) {
      case 'warm':
        return Icons.local_fire_department_outlined;
      case 'cool':
        return Icons.ac_unit_outlined;
      case 'vibrant':
        return Icons.auto_awesome_outlined;
      case 'pale':
        return Icons.opacity_outlined;
      default:
        return Icons.palette_outlined;
    }
  }

  String _getTintLabel(String tint) {
    switch (tint) {
      case 'warm':
        return 'Warm';
      case 'cool':
        return 'Cool';
      case 'vibrant':
        return 'Vibrant';
      case 'pale':
        return 'Pale';
      default:
        return tint;
    }
  }
}

class _UniformBadge extends StatelessWidget {
  final MaterialColor color;
  final Widget child;

  const _UniformBadge({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade400.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade400.withOpacity(0.5)),
      ),
      child: Center(child: child),
    );
  }
}

class _CreatureDisplay extends StatelessWidget {
  final Creature? hydrated;
  final Color fallbackColor;

  const _CreatureDisplay({required this.hydrated, required this.fallbackColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fallbackColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: hydrated != null && hydrated!.spriteData != null
            ? CreatureSprite(
                spritePath: hydrated!.spriteData!.spriteSheetPath,
                totalFrames: hydrated!.spriteData!.totalFrames,
                rows: hydrated!.spriteData!.rows,
                scale: scaleFromGenes(hydrated!.genetics),
                saturation: satFromGenes(hydrated!.genetics),
                brightness: briFromGenes(hydrated!.genetics),
                hueShift: hueFromGenes(hydrated!.genetics),
                isPrismatic: hydrated!.isPrismaticSkin,
                frameSize: Vector2(
                  hydrated!.spriteData!.frameWidth * 1.0,
                  hydrated!.spriteData!.frameHeight * 1.0,
                ),
                stepTime: hydrated!.spriteData!.frameDurationMs / 1000.0,
              )
            : hydrated != null
            ? Image.asset('assets/images/${hydrated!.image}', fit: BoxFit.cover)
            : Icon(Icons.pets, size: 32, color: fallbackColor),
      ),
    );
  }
}

class _PartyFooter extends StatelessWidget {
  final Color accentColor;

  const _PartyFooter({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final party = context.watch<SelectedPartyNotifier>();
    final count = party.members.length;
    final canDeploy = count > 0 && count <= SelectedPartyNotifier.maxSize;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            border: Border(
              top: BorderSide(color: accentColor.withOpacity(0.35)),
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count == 0 ? 'Select Team' : 'Team Ready',
                      style: _TextStyles.labelText,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Selected: $count / ${SelectedPartyNotifier.maxSize}',
                      style: _TextStyles.hint,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: canDeploy
                    ? () => Navigator.pop(context, party.members)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: canDeploy
                        ? Colors.green.shade600
                        : Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: canDeploy
                        ? [
                            BoxShadow(
                              color: Colors.green.shade400.withOpacity(0.4),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Deploy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.15)),
              ),
              child: Icon(
                Icons.pets_outlined,
                size: 48,
                color: _TextStyles.mutedText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: _TextStyles.emptyStateTitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== HELPER CLASSES ====================

class _CreatureHelper {
  static Creature? hydrateCreature(
    CreatureRepository repo,
    CreatureInstance instance,
  ) {
    final base = repo.getCreatureById(instance.baseId);
    var out = base;

    if (instance.isPrismaticSkin) {
      out = out?.copyWith(isPrismaticSkin: true);
    }

    if (instance.natureId != null && instance.natureId!.isNotEmpty) {
      final n = NatureCatalog.byId(instance.natureId!);
      if (n != null) out = out?.copyWith(nature: n);
    }

    final g = decodeGenetics(instance.geneticsJson);
    if (g != null) out = out?.copyWith(genetics: g);

    return out;
  }

  static Map<String, String>? parseGenetics(CreatureInstance instance) {
    if (instance.geneticsJson == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(instance.geneticsJson!));
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      return null;
    }
  }
}

// ==================== TEXT STYLES ====================

class _TextStyles {
  static const softText = Color(0xFFE8EAED);
  static const mutedText = Color(0xFFB6C0CC);

  static const headerTitle = TextStyle(
    color: softText,
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
  );

  static const headerSubtitle = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const sectionTitle = TextStyle(
    color: softText,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const labelText = TextStyle(
    color: softText,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static const hint = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const cardTitle = TextStyle(
    color: softText,
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );

  static const cardTitleDisabled = TextStyle(
    color: Color(0xFF7A8290),
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );

  static const cardSmallTitle = TextStyle(
    color: softText,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  static const emptyStateTitle = TextStyle(
    color: softText,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );
}
