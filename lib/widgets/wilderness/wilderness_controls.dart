// lib/widgets/wilderness/wilderness_controls.dart
import 'package:alchemons/widgets/wilderness/inventory_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/models/wilderness.dart';

/// Simple three-button control panel for wilderness scenes
class WildernessControls extends StatelessWidget {
  final VoidCallback onLeave;
  final List<PartyMember> party;

  const WildernessControls({
    super.key,
    required this.onLeave,
    required this.party,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ControlButton(
              icon: Icons.exit_to_app_rounded,
              color: const Color.fromARGB(255, 95, 33, 29),
              tooltip: 'Leave Scene',
              onPressed: () => _showLeaveConfirmation(context),
            ),
            const SizedBox(height: 8),
            _ControlButton(
              icon: Icons.inventory,
              color: const Color.fromARGB(255, 133, 115, 59),
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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0E27),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withOpacity(0.5), width: 2),
        ),
        title: const Text(
          'Leave Scene?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Any active encounters will be lost. Are you sure you want to leave?',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              onLeave();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showInventoryOverlay(BuildContext context) {
    HapticFeedback.lightImpact();

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.85),
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
          // Darker transparent backdrop
          Container(color: Colors.black.withOpacity(0.1)),

          // Inventory panel - NO EXTRA WRAPPER
          GestureDetector(
            onTap: () {}, // Prevents tap-through
            child: SafeArea(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 32,
                  ),
                  constraints: const BoxConstraints(maxWidth: 450),

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14.5),
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
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton.small(
        heroTag: tooltip,
        backgroundColor: color,
        foregroundColor: Colors.white,
        onPressed: onPressed,
        child: Icon(icon),
      ),
    );
  }
}
