import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum NavSection { home, creatures, shop, enhance, breed, inventory }

class BottomNav extends StatefulWidget {
  const BottomNav({
    super.key,
    required this.current,
    required this.onSelect,
    this.theme,
  });

  final NavSection current;
  final ValueChanged<NavSection> onSelect;
  final FactionTheme? theme;

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> with TickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      _expandController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _expandController.stop();
    _expandController.dispose();
    super.dispose();
  }

  void _handleTap(NavSection section) {
    HapticFeedback.mediumImpact();
    widget.onSelect(section);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.theme!.isDark;
    return Container(
      decoration: BoxDecoration(color: widget.theme?.surfaceAlt),
      clipBehavior: Clip.none,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(
                NavSection.inventory,
                'assets/images/ui/inventorylight.png',
                'INVENTORY',
              ),
              _buildNavButton(
                NavSection.creatures,
                isDark
                    ? 'assets/images/ui/dexicon_light.png'
                    : 'assets/images/ui/dexicon.png',
                'CREATURES',
              ),
              _buildNavButton(
                NavSection.home,
                'assets/images/ui/homeicon2.png',
                'HOME',
              ),
              _buildNavButton(
                NavSection.breed,
                'assets/images/ui/breedicon.png',
                'FUSION',
              ),

              _buildNavButton(
                NavSection.shop,
                'assets/images/ui/shopicon2.png',
                'SHOP',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(NavSection section, dynamic icon, String label) {
    final isActive = widget.current == section;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final size = isActive ? (48.0 + (_expandAnimation.value * 32)) : 48.0;
        final verticalOffset = isActive ? -(_expandAnimation.value * 30) : 0.0;

        final iconSize = isActive
            ? (40.0 + (_expandAnimation.value * 40))
            : 55.0;

        return Transform.translate(
          offset: Offset(0, verticalOffset),
          child: GestureDetector(
            onTap: () => _handleTap(section),
            child: SizedBox(
              width: size,
              height: size,
              // 👇 this is the important part
              child: OverflowBox(
                // allow child to paint bigger than `size`
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon is IconData)
                      Icon(
                        icon,
                        color: isActive
                            ? widget.theme?.accent
                            : widget.theme?.textMuted,
                        size: iconSize,
                      )
                    else if (icon is String)
                      SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: Image.asset(icon, fit: BoxFit.contain),
                        ),
                      ),
                    if (isActive) ...[
                      Opacity(
                        opacity: _expandAnimation.value,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: widget.theme?.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
