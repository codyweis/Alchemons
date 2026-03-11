// lib/widgets/wilderness/wilderness_controls.dart
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/wilderness/inventory_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:provider/provider.dart';

/// Simple three-button control panel for wilderness scenes
class WildernessControls extends StatelessWidget {
  final VoidCallback onLeave;
  final List<PartyMember> party;
  final String leaveTooltip;
  final String leaveDialogTitle;
  final String leaveDialogBody;
  final String leaveConfirmLabel;
  final String leaveCancelLabel;

  const WildernessControls({
    super.key,
    required this.onLeave,
    required this.party,
    this.leaveTooltip = 'Leave Scene',
    this.leaveDialogTitle = 'LEAVE SCENE?',
    this.leaveDialogBody = 'Any active encounters will be lost.',
    this.leaveConfirmLabel = 'LEAVE',
    this.leaveCancelLabel = 'CANCEL',
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ControlButton(
              icon: Icons.exit_to_app_rounded,
              bgColor: t.danger.withValues(alpha: 0.85),
              borderColor: t.danger,
              glowColor: t.danger,
              tooltip: leaveTooltip,
              onPressed: () => _showLeaveConfirmation(context),
            ),
            const SizedBox(width: 8),
            _ControlButton(
              icon: Icons.inventory_2_rounded,
              bgColor: t.bg2,
              borderColor: t.borderAccent,
              glowColor: t.amber,
              tooltip: 'Inventory',
              onPressed: () => _showInventoryOverlay(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveConfirmation(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) {
        final t2 = ForgeTokens(ctx.read<FactionTheme>());
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: t2.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: t2.danger.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: t2.bg2,
                    border: Border(bottom: BorderSide(color: t2.borderDim)),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: t2.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        leaveDialogTitle,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t2.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    leaveDialogBody,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t2.textSecondary,
                      fontSize: 11,
                      letterSpacing: 0.3,
                      height: 1.6,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: t2.bg2,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: t2.borderDim),
                          ),
                          child: Text(
                            leaveCancelLabel,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t2.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          Navigator.pop(ctx);
                          onLeave();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: t2.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: t2.danger),
                          ),
                          child: Text(
                            leaveConfirmLabel,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t2.danger,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showInventoryOverlay(BuildContext context) {
    HapticFeedback.lightImpact();

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const _InventoryOverlayShell(),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }
}

class _InventoryOverlayShell extends StatelessWidget {
  const _InventoryOverlayShell();

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Container(color: Colors.black.withValues(alpha: 0.1)),
          GestureDetector(
            onTap: () {},
            child: SafeArea(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 32,
                  ),
                  constraints: const BoxConstraints(maxWidth: 450),
                  decoration: BoxDecoration(
                    color: t.bg1,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: t.borderAccent, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: t.amber.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const GameInventoryOverlay(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color glowColor;
  final String tooltip;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.glowColor,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
