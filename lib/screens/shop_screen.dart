import 'dart:ui';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/interactive_background_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  int _slotsUnlocked = 1;
  bool _showPurchased = false;

  late final AnimationController _rotationCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _waveCtrl;

  late final Map<String, int> _slot2Cost;
  late final Map<String, int> _slot3Cost;

  @override
  void initState() {
    super.initState();

    // Build once from element names (human-readable & future-proof)
    _slot2Cost = ElementResources.costByElements({
      'Fire': 60,
      'Water': 60,
      'Air': 60,
      'Earth': 60,
    });
    _slot3Cost = ElementResources.costByElements({
      'Fire': 140,
      'Water': 140,
      'Air': 140,
      'Earth': 140,
    });

    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Start heavy animations after the first frame to avoid push-transition jank
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rotationCtrl.repeat();
      _particleCtrl.repeat();
      _waveCtrl.repeat();
    });

    _refreshAll();
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _particleCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  ({double particle, double rotation, double elemental}) _speedFor(
    FactionId f,
  ) {
    switch (f) {
      case FactionId.fire:
        return (particle: .1, rotation: 0.1, elemental: .3);
      case FactionId.water:
        return (particle: 1, rotation: 0.1, elemental: .5);
      case FactionId.air:
        return (particle: 1, rotation: 0.1, elemental: 1);
      case FactionId.earth:
        return (particle: 1, rotation: 0.1, elemental: 0.2);
    }
  }

  Future<void> _refreshAll() async {
    final db = context.read<AlchemonsDatabase>();
    final n = await db.getBlobSlotsUnlocked();
    final show = await db.getShopShowPurchased();
    if (!mounted) return;
    setState(() {
      _slotsUnlocked = n;
      _showPurchased = show;
    });
  }

  Future<void> _purchaseSlot(int target) async {
    final db = context.read<AlchemonsDatabase>();
    final cost = target == 2 ? _slot2Cost : _slot3Cost;

    if (_slotsUnlocked >= target) {
      _toast('Already unlocked');
      return;
    }

    final ok = await db.spendResources(cost);
    if (!ok) {
      _toast(
        'Not enough resources',
        icon: Icons.lock_rounded,
        color: Colors.orange,
      );
      return;
    }

    await db.setBlobSlotsUnlocked(target);
    await _refreshAll();
    _toast(
      'Bubble slot $target unlocked!',
      icon: Icons.bubble_chart_rounded,
      color: Colors.lightBlueAccent,
    );
    HapticFeedback.lightImpact();
  }

  void _toast(String msg, {IconData icon = Icons.check_rounded, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: color ?? Colors.teal,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final faction = context.read<FactionService>().current!;
    final (primary, secondary, accent) = getFactionColors(faction);
    final speeds = _speedFor(faction);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            InteractiveBackground(
              particleController: _particleCtrl,
              rotationController: _rotationCtrl,
              waveController: _waveCtrl,
              primaryColor: primary,
              secondaryColor: secondary,
              accentColor: accent,
              factionType: faction,
              particleSpeed: speeds.particle,
              rotationSpeed: speeds.rotation,
              elementalSpeed: speeds.elemental,
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x660B0F14), Color(0x440B0F14)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Filter row (Show purchased)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _ShowPurchasedSegmented(
                        value: _showPurchased,
                        accent: accent,
                        onChanged: (v) async {
                          setState(() => _showPurchased = v);
                          await context
                              .read<AlchemonsDatabase>()
                              .setShopShowPurchased(v);
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _Glass(
                      border: accent,
                      child: Row(
                        children: [
                          Icon(Icons.shopping_bag_rounded, color: accent),
                          const SizedBox(width: 10),
                          const Text(
                            'RESEARCH SHOP',
                            style: TextStyle(
                              color: Color(0xFFE8EAED),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Balances (compact with positives + featured)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _BalancesBarCompact(accent: accent),
                  ),

                  // Tabs
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _Glass(
                      border: accent,
                      child: TabBar(
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        indicatorColor: accent,
                        tabs: const [
                          Tab(text: 'Resources'),
                          Tab(text: 'Premium'),
                        ],
                      ),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildResourceShop(accent),
                        _buildPremiumComingSoon(accent),
                      ],
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

  Widget _buildResourceShop(Color accent) {
    final cards = <Widget>[];

    // Bubble slot 2
    final slot2Enabled = _slotsUnlocked < 2;
    if (slot2Enabled || _showPurchased) {
      cards.add(
        _ShopItemCard(
          title: slot2Enabled
              ? 'Unlock Bubble Slot 2'
              : 'Bubble Slot 2 (Unlocked)',
          subtitle: 'Display a second floating creature bubble.',
          accent: accent,
          cost: _slot2Cost,
          enabled: slot2Enabled,
          onPressed: () => _purchaseSlot(2),
        ),
      );
      cards.add(const SizedBox(height: 12));
    }

    // Bubble slot 3
    final slot3Enabled = _slotsUnlocked < 3;
    if (slot3Enabled || _showPurchased) {
      cards.add(
        _ShopItemCard(
          title: slot3Enabled
              ? 'Unlock Bubble Slot 3'
              : 'Bubble Slot 3 (Unlocked)',
          subtitle: 'Display a third floating creature bubble.',
          accent: accent,
          cost: _slot3Cost,
          enabled: slot3Enabled,
          onPressed: () => _purchaseSlot(3),
        ),
      );
      cards.add(const SizedBox(height: 20));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          _SectionTitle(title: 'Upgrades', accent: accent),
          ...cards,
          _SectionTitle(title: 'Farms', accent: accent),
          _FarmUnlockColumn(accent: accent, showPurchased: _showPurchased),
        ],
      ),
    );
  }

  Widget _buildPremiumComingSoon(Color accent) {
    return Center(
      child: Opacity(
        opacity: 0.85,
        child: _Glass(
          border: accent,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.credit_card_rounded, color: Colors.white70, size: 28),
              SizedBox(height: 10),
              Text(
                'Premium tab coming soon',
                style: TextStyle(
                  color: Color(0xFFE8EAED),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----- widgets -----

class _ShowPurchasedSegmented extends StatelessWidget {
  const _ShowPurchasedSegmented({
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final bool value; // false: Available, true: All (show purchased)
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const h = 30.0;
    const w = 148.0;
    final knobW = (w - 6) / 2;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: w,
        height: h,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: accent.withOpacity(0.45), width: 1),
          boxShadow: value
              ? [BoxShadow(color: accent.withOpacity(0.20), blurRadius: 12)]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 10,
                  ),
                ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: Container(
                width: knobW,
                height: h - 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: accent.withOpacity(0.22),
                  border: Border.all(color: accent.withOpacity(0.8)),
                  boxShadow: [
                    BoxShadow(color: accent.withOpacity(0.3), blurRadius: 8),
                  ],
                ),
              ),
            ),
            Row(
              children: const [
                _SegLabel(
                  text: 'Available',
                  active: true,
                ), // style overridden by AnimatedDefaultTextStyle
                _SegLabel(text: 'All', active: false),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SegLabel extends StatelessWidget {
  const _SegLabel({required this.text, required this.active});
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          style: TextStyle(
            color: active ? const Color(0xFFE8EAED) : Colors.white70,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            fontSize: 10.5,
            letterSpacing: 0.35,
          ),
          child: Text(text),
        ),
      ),
    );
  }
}

class _BalancesBarCompact extends StatelessWidget {
  const _BalancesBarCompact({required this.accent});
  final Color accent;

  // Fallback featured keys if player has zero of everything
  static const _featuredKeys = <String>{
    'res_embers',
    'res_droplets',
    'res_breeze',
    'res_shards',
  };

  String _fmt(int n) {
    if (n >= 1000000000) return '${(n / 1e9).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1e3).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();

    return StreamBuilder<Map<String, int>>(
      stream: db.watchResourceBalances(),
      builder: (context, snap) {
        final balances =
            snap.data ??
            {for (final e in ElementResources.all) e.settingsKey: 0};

        // Show ALL resources with balance > 0 in compact row (sorted by value desc).
        final positives =
            ElementResources.all
                .where((r) => (balances[r.settingsKey] ?? 0) > 0)
                .toList()
              ..sort(
                (a, b) => (balances[b.settingsKey] ?? 0).compareTo(
                  balances[a.settingsKey] ?? 0,
                ),
              );

        // If none >0, fall back to a small set of featured.
        final shown = positives.isNotEmpty
            ? positives
            : ElementResources.all
                  .where((r) => _featuredKeys.contains(r.settingsKey))
                  .toList();

        return _Glass(
          border: accent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 2, right: 8),
                child: Text(
                  'Resources',
                  style: TextStyle(
                    color: Color(0xFFE8EAED),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.35,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final r in shown) ...[
                        _MiniResPill(
                          icon: r.icon,
                          color: r.color,
                          label: r.resLabel,
                          value: balances[r.settingsKey] ?? 0,
                          fmt: _fmt,
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    _openAllResourcesSheet(context, balances, accent),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'All',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAllResourcesSheet(
    BuildContext context,
    Map<String, int> balances,
    Color accent,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _Glass(
                border: accent,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.grid_view_rounded, color: accent),
                        const SizedBox(width: 8),
                        const Text(
                          'All Elements',
                          style: TextStyle(
                            color: Color(0xFFE8EAED),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          // Responsive columns for compact sheet
                          final cross = (c.maxWidth / 120).floor().clamp(2, 6);
                          return GridView.builder(
                            controller: controller,
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cross,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  mainAxisExtent: 52,
                                ),
                            itemCount: ElementResources.all.length,
                            itemBuilder: (_, i) {
                              final res = ElementResources.all[i];
                              final v = balances[res.settingsKey] ?? 0;
                              return _GridResTile(
                                icon: res.icon,
                                color: res.color,
                                label: res.resLabel,
                                value: v,
                                fmt: _fmt,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniResPill extends StatelessWidget {
  const _MiniResPill({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.fmt,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final String Function(int) fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.18),
              border: Border.all(color: color.withOpacity(0.65)),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.22), blurRadius: 8),
              ],
            ),
            child: Icon(icon, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE8EAED),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            fmt(value),
            style: const TextStyle(
              color: Color(0xFFE8EAED),
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridResTile extends StatelessWidget {
  const _GridResTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.fmt,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final String Function(int) fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.18),
              border: Border.all(color: color.withOpacity(0.6)),
            ),
            child: Icon(icon, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE8EAED),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            fmt(value),
            style: const TextStyle(
              color: Color(0xFFE8EAED),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.accent});
  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFE8EAED),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  const _ShopItemCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.cost,
    required this.enabled,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Map<String, int> cost;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: _Glass(
        border: accent,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.bubble_chart_rounded,
              color: Colors.white70,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFE8EAED),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _CostPill(
                        label: 'Embers',
                        amount: cost['res_embers'] ?? 0,
                      ),
                      _CostPill(
                        label: 'Droplets',
                        amount: cost['res_droplets'] ?? 0,
                      ),
                      _CostPill(
                        label: 'Breeze',
                        amount: cost['res_breeze'] ?? 0,
                      ),
                      _CostPill(
                        label: 'Shards',
                        amount: cost['res_shards'] ?? 0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: enabled ? onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: enabled ? accent : Colors.white24,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CostPill extends StatelessWidget {
  const _CostPill({required this.label, required this.amount});
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.blur_on_rounded, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            '$label $amount',
            style: const TextStyle(
              color: Color(0xFFE8EAED),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Hides unlocked items when showPurchased=false
class _FarmUnlockColumn extends StatelessWidget {
  const _FarmUnlockColumn({required this.accent, required this.showPurchased});
  final Color accent;
  final bool showPurchased;

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();

    // You can move these to constants if you want them reused elsewhere.
    final fire = ElementResources.costByElements({
      'Fire': 0,
      'Water': 40,
      'Air': 20,
      'Earth': 20,
    });
    final water = ElementResources.costByElements({
      'Fire': 40,
      'Water': 0,
      'Air': 20,
      'Earth': 20,
    });
    final air = ElementResources.costByElements({
      'Fire': 20,
      'Water': 20,
      'Air': 0,
      'Earth': 40,
    });
    final earth = ElementResources.costByElements({
      'Fire': 20,
      'Water': 20,
      'Air': 40,
      'Earth': 0,
    });

    Future<Widget?> card(
      String label,
      String element,
      Map<String, int> cost,
    ) async {
      final farm = await db.getFarmByElement(element);
      final unlocked = farm?.unlocked == true;

      if (unlocked && !showPurchased) return null; // hide if purchased

      return _ShopItemCard(
        title: unlocked ? '$label Farm (Unlocked)' : 'Unlock $label Farm',
        subtitle: unlocked
            ? 'Produces $label resources. Upgrades coming soon.'
            : 'Enable $label resource production in the Field.',
        accent: accent,
        cost: cost,
        enabled: !unlocked,
        onPressed: () async {
          final ok = await db.unlockFarm(element: element, cost: cost);
          final msg = ok ? '$label farm unlocked!' : 'Not enough resources';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        },
      );
    }

    return FutureBuilder<List<Widget?>>(
      future: Future.wait([
        card('Fire', 'fire', fire),
        card('Water', 'water', water),
        card('Air', 'air', air),
        card('Earth', 'earth', earth),
      ]),
      builder: (context, snap) {
        final children = (snap.data ?? const []).whereType<Widget>().toList();

        if (children.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Opacity(
              opacity: 0.8,
              child: Text(
                'No items available here.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              children[i],
            ],
          ],
        );
      },
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.padding, required this.border});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border.withOpacity(.35), width: 1),
            boxShadow: [
              BoxShadow(
                color: border.withOpacity(.18),
                blurRadius: 18,
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
