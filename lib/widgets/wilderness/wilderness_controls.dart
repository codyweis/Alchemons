// lib/widgets/wilderness/wilderness_controls.dart
import 'package:alchemons/constants/design_tokens.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/wilderness/inventory_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/widgets/app_icons.dart';

// Wilderness HUD sits on dark scene backdrops — always dark.
const _wPalette = BracketPalette.dark;
const _wDanger = Color(0xFFC0392B);
const _wAmber = Color(0xFFE4C16A);

/// Compact wilderness HUD controls for leaving the scene and opening items.
class WildernessControls extends StatelessWidget {
  final VoidCallback onLeave;
  final List<PartyMember> party;
  final String leaveTooltip;
  final String leaveDialogTitle;
  final String leaveDialogBody;
  final String leaveConfirmLabel;
  final String leaveCancelLabel;

  /// Optional gate: when it returns false, the leave confirmation is suppressed
  /// and [onLeaveBlocked] is invoked instead.
  final bool Function()? canLeave;
  final VoidCallback? onLeaveBlocked;

  const WildernessControls({
    super.key,
    required this.onLeave,
    required this.party,
    this.leaveTooltip = 'Leave Scene',
    this.leaveDialogTitle = 'LEAVE SCENE?',
    this.leaveDialogBody = 'Any active encounters will be lost.',
    this.leaveConfirmLabel = 'LEAVE',
    this.leaveCancelLabel = 'CANCEL',
    this.canLeave,
    this.onLeaveBlocked,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            // Exit stays anchored top-left.
            Align(
              alignment: Alignment.topLeft,
              child: _ControlButton(
                label: 'Exit',
                icon: AppIcons.exit_to_app_rounded,
                accentColor: _wDanger,
                tooltip: leaveTooltip,
                onPressed: () => _showLeaveConfirmation(context),
              ),
            ),
            // Items moved down to the bottom-left corner.
            Align(
              alignment: Alignment.bottomLeft,
              child: _ControlButton(
                label: 'Items',
                icon: AppIcons.inventory_2_rounded,
                accentColor: _wAmber,
                tooltip: 'Inventory',
                onPressed: () => _showInventoryOverlay(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveConfirmation(BuildContext context) {
    if (canLeave != null && !canLeave!()) {
      onLeaveBlocked?.call();
      return;
    }
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: CustomPaint(
              painter: BracketFramePainter(
                color: _wDanger.withValues(alpha: 0.85),
                bracketSize: 12,
                strokeWidth: 1.3,
              ),
              child: Container(
                color: _wPalette.surfaceFill(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 26,
                            color: _wDanger,
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Text(
                              _toSentenceCase(leaveDialogTitle),
                              style: bracketText(
                                ctx,
                                17,
                                _wPalette.ink,
                                weight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      child: Text(
                        leaveDialogBody,
                        style: bracketText(
                          ctx,
                          12.5,
                          _wPalette.muted,
                          weight: FontWeight.w500,
                        ),
                        strutStyle: const StrutStyle(height: 1.4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: _DialogButton(
                              label: _toSentenceCase(leaveCancelLabel),
                              color: _wPalette.muted,
                              filled: false,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: _DialogButton(
                              label: _toSentenceCase(leaveConfirmLabel),
                              color: _wDanger,
                              filled: true,
                              onTap: () {
                                HapticFeedback.heavyImpact();
                                Navigator.pop(ctx);
                                onLeave();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _toSentenceCase(String v) {
    if (v.isEmpty) return v;
    final lower = v.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
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
                  child: CustomPaint(
                    painter: BracketFramePainter(
                      color: _wAmber.withValues(alpha: 0.8),
                      bracketSize: 12,
                      strokeWidth: 1.3,
                    ),
                    child: ColoredBox(
                      color: _wPalette.surfaceFill(),
                      child: const GameInventoryOverlay(),
                    ),
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
  final String label;
  final IconData icon;
  final Color accentColor;
  final String tooltip;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: BracketFramePainter(
            color: accentColor.withValues(alpha: 0.8),
            bracketSize: 8,
            strokeWidth: 1.1,
          ),
          child: Container(
            constraints: const BoxConstraints(minWidth: 66, minHeight: 54),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm,
            ),
            color: _wPalette.surfaceFill(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accentColor, size: AppIcon.md),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: bracketText(
                    context,
                    10.5,
                    _wPalette.ink,
                    weight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: BracketFramePainter(
          color: filled ? color : color.withValues(alpha: 0.6),
          bracketSize: 8,
          strokeWidth: filled ? 1.3 : 1.1,
        ),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          color: filled
              ? color
              : color.withValues(alpha: 0.10),
          child: Text(
            label,
            style: bracketText(
              context,
              13,
              filled ? Colors.white : color,
              weight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
