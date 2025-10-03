// lib/screens/harvest_screen.dart
import 'dart:ui';
import 'dart:math' as math;

import 'package:alchemons/widgets/glowing_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/farm_element.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/screens/harvest_detail_screen.dart';

class HarvestScreen extends StatefulWidget {
  const HarvestScreen({super.key, this.service});

  final HarvestService? service;

  @override
  State<HarvestScreen> createState() => _HarvestScreenState();
}

class _HarvestScreenState extends State<HarvestScreen>
    with TickerProviderStateMixin {
  late HarvestService svc;
  late final AnimationController _bg;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    svc = widget.service ?? context.read<HarvestService>();
    _bg = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bg.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _promptUnlock(HarvestFarmState f) async {
    final costDb = _unlockCostToKeys(f.element.unlockCostDb);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _UnlockDialog(element: f.element, costDb: costDb),
    );

    if (confirmed == true) {
      final ok = await svc.unlock(f.element, cost: costDb);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Unlocked ${f.element.label}!' : 'Not enough resources',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final farms = svc.farms;
    // Use color from first unlocked farm, or a default
    final accentColor = farms
        .firstWhere((f) => f.unlocked, orElse: () => farms.first)
        .element
        .color;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bg,
              builder: (_, __) =>
                  CustomPaint(painter: _HarvestBackdropPainter(t: _bg.value)),
            ),
          ),
          Column(
            children: [
              _buildHeader(accentColor),
              Expanded(
                child: AnimatedBuilder(
                  animation: svc,
                  builder: (_, __) {
                    final width = MediaQuery.of(context).size.width;
                    final cross = width >= 900
                        ? 4
                        : width >= 650
                        ? 3
                        : 2;
                    final aspect = width >= 650 ? .95 : .93;

                    return GridView.builder(
                      padding: const EdgeInsets.all(14),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: aspect,
                      ),
                      itemCount: farms.length,
                      itemBuilder: (_, i) {
                        final f = farms[i];
                        return _FarmCard(
                          f: f,
                          onUnlock: () => _promptUnlock(f),
                          onOpen: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                transitionDuration: const Duration(
                                  milliseconds: 450,
                                ),
                                pageBuilder: (_, a1, __) => FadeTransition(
                                  opacity: CurvedAnimation(
                                    parent: a1,
                                    curve: Curves.ease,
                                  ),
                                  child: HarvestDetailScreen(
                                    element: f.element,
                                    service: svc,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    return SafeArea(
      bottom: false,
      child: Padding(
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
                      Text(
                        'RESOURCE HARVESTING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: accentColor.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Extract elemental resources from active farms',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                GlowingIcon(
                  icon: Icons.agriculture_rounded,
                  color: accentColor,
                  controller: _glowController,
                  dialogTitle: "Resource Harvesting",
                  dialogMessage:
                      "Set up and manage farms to extract valuable elemental resources over time. Unlock new farms with unique elements and upgrade existing ones to boost efficiency and yield.",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, int> _unlockCostToKeys(Map<String, int> uiCost) {
    final map = <String, int>{};
    for (final e in uiCost.entries) {
      final k = switch (e.key.toLowerCase()) {
        'embers' => 'res_embers',
        'droplets' => 'res_droplets',
        'breeze' => 'res_breeze',
        'shards' => 'res_shards',
        _ => e.key,
      };
      map[k] = e.value;
    }
    return map;
  }
}

// =================== Glass Header Components ===================

class _GlassContainer extends StatelessWidget {
  const _GlassContainer({
    required this.accentColor,
    required this.glowController,
    required this.child,
  });

  final Color accentColor;
  final AnimationController glowController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowController,
      builder: (context, _) {
        final glowIntensity = 0.15 + (glowController.value * 0.15);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(0.08),
                    Colors.black.withOpacity(0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(glowIntensity),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.accentColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            widget.icon,
            color: Colors.white.withOpacity(0.9),
            size: 20,
          ),
        ),
      ),
    );
  }
}

// =================== Card ===================

class _FarmCard extends StatefulWidget {
  const _FarmCard({
    required this.f,
    required this.onUnlock,
    required this.onOpen,
  });

  final HarvestFarmState f;
  final VoidCallback onUnlock;
  final VoidCallback onOpen;

  @override
  State<_FarmCard> createState() => _FarmCardState();
}

class _FarmCardState extends State<_FarmCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.f.element;
    final color = e.color;
    final unlocked = widget.f.unlocked;
    final hasActive = widget.f.active != null;
    final completed = widget.f.completed;
    final remaining = widget.f.remaining;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _down ? .98 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(.10),
                    Colors.black.withOpacity(.22),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(.28), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(.22),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -30,
                    right: -20,
                    child: _Orb(color: color.withOpacity(.20), size: 120),
                  ),
                  Positioned(
                    bottom: -26,
                    left: -16,
                    child: _Orb(color: color.withOpacity(.16), size: 110),
                  ),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _shine,
                      builder: (_, __) {
                        final p = _shine.value;
                        return IgnorePointer(
                          child: ShaderMask(
                            blendMode: BlendMode.plus,
                            shaderCallback: (rect) {
                              final dx = rect.width * (p * 1.25 - .2);
                              return LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.transparent,
                                  color.withOpacity(.18),
                                  Colors.transparent,
                                ],
                                stops: const [0.35, 0.5, 0.65],
                              ).createShader(
                                Rect.fromLTWH(
                                  dx,
                                  0,
                                  rect.width * .22,
                                  rect.height,
                                ),
                              );
                            },
                            child: Container(color: Colors.transparent),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: AnimatedBuilder(
                      animation: _shine,
                      builder: (_, __) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        color.withOpacity(.50),
                                        color.withOpacity(.08),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: color.withOpacity(.55),
                                      width: 1.6,
                                    ),
                                  ),
                                  child: Icon(e.icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    e.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFE8EAED),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      letterSpacing: .2,
                                    ),
                                  ),
                                ),
                                _StatusChip(
                                  color: color,
                                  text: !unlocked
                                      ? 'LOCKED'
                                      : (hasActive
                                            ? (completed ? 'READY' : 'ACTIVE')
                                            : 'READY'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (!unlocked) ...[
                              const Spacer(),
                              _AccentBtn(
                                label: 'Unlock',
                                icon: Icons.lock_open_rounded,
                                color: color,
                                filled: true,
                                onTap: widget.onUnlock,
                              ),
                            ] else ...[
                              Text(
                                hasActive
                                    ? (completed
                                          ? 'Extraction complete — ready to collect.'
                                          : 'Extraction in progress…')
                                    : 'No active extraction — open to start',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.78),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (hasActive) ...[
                                _MetaRow(
                                  children: [
                                    if (!completed && remaining != null)
                                      _TinyPill(
                                        icon: Icons.schedule_rounded,
                                        label:
                                            'ETA ${TimeOfDay.fromDateTime(DateTime.now().add(remaining)).format(context)}',
                                      ),
                                    if (completed)
                                      const _TinyPill(
                                        icon: Icons.check_circle_rounded,
                                        label: 'Ready to collect',
                                      ),
                                  ],
                                ),
                              ] else
                                const _MetaRow(
                                  children: [
                                    _TinyPill(
                                      icon: Icons.hourglass_empty_rounded,
                                      label: 'No active job',
                                    ),
                                  ],
                                ),
                              const Spacer(),
                              _AccentBtn(
                                label: 'Open',
                                icon: Icons.chevron_right_rounded,
                                color: color,
                                filled: false,
                                onTap: widget.onOpen,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =================== Helper Widgets ===================

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 6, children: children);
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withOpacity(.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE8EAED),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = text.toLowerCase();

    late final IconData icon;
    late final Color bg;
    late final Color border;
    late final Color fg;

    switch (t) {
      case 'locked':
        icon = Icons.lock_outline_rounded;
        bg = Colors.white.withOpacity(.06);
        border = Colors.white.withOpacity(.16);
        fg = const Color(0xFFE8EAED).withOpacity(.85);
        break;
      case 'active':
        icon = Icons.bolt_rounded;
        bg = color.withOpacity(.20);
        border = color.withOpacity(.55);
        fg = Colors.white.withOpacity(.95);
        break;
      default:
        icon = Icons.check_circle_rounded;
        bg = color.withOpacity(.14);
        border = color.withOpacity(.45);
        fg = Colors.white.withOpacity(.95);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentBtn extends StatelessWidget {
  const _AccentBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color.withOpacity(.28) : Colors.white.withOpacity(.06);
    final border = filled
        ? color.withOpacity(.55)
        : Colors.white.withOpacity(.18);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.6),
          boxShadow: [
            if (filled)
              BoxShadow(color: color.withOpacity(.28), blurRadius: 16),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white.withOpacity(.95)),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * .45,
              spreadRadius: size * .12,
            ),
          ],
        ),
      ),
    );
  }
}

// =================== Unlock dialog ===================

class _UnlockDialog extends StatelessWidget {
  const _UnlockDialog({required this.element, required this.costDb});

  final FarmElement element;
  final Map<String, int> costDb;

  String _prettyRes(String k) {
    switch (k.toLowerCase()) {
      case 'res_embers':
      case 'embers':
        return 'Embers';
      case 'res_droplets':
      case 'droplets':
        return 'Droplets';
      case 'res_breeze':
      case 'breeze':
        return 'Breeze';
      case 'res_shards':
      case 'shards':
        return 'Shards';
      default:
        return k;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = element.color;
    final db = context.read<AlchemonsDatabase>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(.75),
                  Colors.black.withOpacity(.55),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(.35), width: 1.6),
              boxShadow: [
                BoxShadow(color: color.withOpacity(.25), blurRadius: 24),
              ],
            ),
            child: StreamBuilder<Map<String, int>>(
              stream: db.watchResourceBalances(),
              builder: (context, snap) {
                final bal =
                    snap.data ??
                    const {
                      'res_embers': 0,
                      'res_droplets': 0,
                      'res_breeze': 0,
                      'res_shards': 0,
                    };

                bool hasShortage = false;
                for (final e in costDb.entries) {
                  final have = bal[e.key] ?? 0;
                  if (have < e.value) {
                    hasShortage = true;
                    break;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  color.withOpacity(.5),
                                  color.withOpacity(.08),
                                ],
                              ),
                              border: Border.all(
                                color: color.withOpacity(.55),
                                width: 1.6,
                              ),
                            ),
                            child: Icon(element.icon, color: color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Unlock ${element.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE8EAED),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Required resources',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.75),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...costDb.entries.map((e) {
                        final name = _prettyRes(e.key);
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
                            color: Colors.white.withOpacity(.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: ok
                                  ? color.withOpacity(.45)
                                  : Colors.red.withOpacity(.45),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _resIcon(name),
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
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
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
                              label: hasShortage
                                  ? 'Not enough'
                                  : 'Confirm Unlock',
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
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _resIcon(String name) {
    switch (name.toLowerCase()) {
      case 'embers':
        return Icons.local_fire_department_rounded;
      case 'droplets':
        return Icons.water_drop_rounded;
      case 'breeze':
        return Icons.air_rounded;
      case 'shards':
        return Icons.landslide_rounded;
      default:
        return Icons.circle;
    }
  }
}

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
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      alignment: Alignment.center,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFE8EAED),
          fontWeight: FontWeight.w900,
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
          gradient: LinearGradient(colors: [color, color.withOpacity(.85)]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(.18)),
          boxShadow: [BoxShadow(color: color.withOpacity(.28), blurRadius: 18)],
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ),
    ),
  );
}

// =================== Background painter ===================

class _HarvestBackdropPainter extends CustomPainter {
  _HarvestBackdropPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0B0F14);
    canvas.drawRect(Offset.zero & size, bg);

    final pathPaint = Paint()
      ..color = Colors.white.withOpacity(.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (int i = 0; i < 3; i++) {
      final pth = Path();
      final amp = 16.0 + i * 10;
      final spd = (t + i * .2) * 2 * math.pi;
      for (double x = 0; x <= size.width; x += 12) {
        final y = size.height * (0.25 + i * .25) + math.sin(x / 80 + spd) * amp;
        if (x == 0) {
          pth.moveTo(x, y);
        } else {
          pth.lineTo(x, y);
        }
      }
      canvas.drawPath(pth, pathPaint);
    }

    final dot = Paint()..color = Colors.white.withOpacity(.08);
    for (int i = 0; i < 40; i++) {
      final px = (i * 37 + t * size.width) % size.width;
      final py = (size.height * (0.15 + (i % 5) * .18)) % size.height;
      final r = 1.2 + math.sin((t + i) * 2 * math.pi) * .6;
      canvas.drawCircle(Offset(px, py), r, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _HarvestBackdropPainter oldDelegate) =>
      oldDelegate.t != t;
}
