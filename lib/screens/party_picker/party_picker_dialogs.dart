import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/widgets/app_icons.dart';

// ---------- DEPLOY CONFIRM DIALOG ----------

class DeployConfirmDialog extends StatelessWidget {
  const DeployConfirmDialog({
    super.key,
    required this.theme,
    this.partyCount = 0,
    this.maxSize = 0,
    this.availableCount = 0,
  });
  final FactionTheme theme;

  /// How many are being deployed, the most that can be, and how many the
  /// player actually owns. The short-party warning lives here rather than on
  /// the way into the field, so it appears while there is still a picker open
  /// to act on it.
  final int partyCount;
  final int maxSize;
  final int availableCount;

  /// Only worth saying when the player could actually field a full team.
  /// Telling someone with three creatures that they are short of four is
  /// noise they cannot act on.
  bool get _shortHanded =>
      maxSize > 0 && partyCount < maxSize && availableCount >= maxSize;

  @visibleForTesting
  bool get shortHandedForTest => _shortHanded;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.bg0,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.warning_amber_rounded,
                    color: t.amberBright,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DEPLOY TEAM?',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: t.borderDim),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_shortHanded) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          AppIcons.warning_amber_rounded,
                          color: t.amberBright,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Deploying $partyCount of $maxSize. You have enough '
                            'creatures to fill the team.',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.amberBright,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'Creatures in the wild are unique and will not be there again after leaving.',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Cancel
                      Expanded(
                        child: GestureDetector(
                          onTap: context.soundAction(() {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context, false);
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: t.bg2,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: t.borderDim),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'CANCEL',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Deploy
                      Expanded(
                        child: GestureDetector(
                          onTap: context.soundAction(() {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context, true);
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: t.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: t.success.withValues(alpha: 0.5),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'DEPLOY',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.success,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 1.0,
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
          ],
        ),
      ),
    );
  }
}
