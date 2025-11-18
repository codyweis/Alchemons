import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';

// ---------- DEPLOY CONFIRM DIALOG ----------

class DeployConfirmDialog extends StatelessWidget {
  const DeployConfirmDialog({super.key, required this.theme});
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withOpacity(.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(.5), width: 1.4),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber.withOpacity(.9),
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              'Deploy Team?',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Are you sure you want to deploy this team to the wild? Creatures in the wild are unique and will not be there again after leaving.",
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Cancel button
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(.14),
                          width: 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: theme.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Deploy button
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(.6),
                          width: 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'DEPLOY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- ZERO STAMINA WARNING DIALOG ----------

class ZeroStaminaWarningDialog extends StatelessWidget {
  const ZeroStaminaWarningDialog({super.key, required this.theme});
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withOpacity(.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(.6), width: 1.4),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber.withOpacity(.95),
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              'Low Stamina Detected',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to proceed? One or more Alchemons has 0 stamina.',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(.14),
                          width: 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: theme.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.amber.withOpacity(.7),
                          width: 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'PROCEED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
