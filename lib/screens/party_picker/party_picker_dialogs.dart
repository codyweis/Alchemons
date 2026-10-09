import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------- DEPLOY CONFIRM DIALOG ----------

/// Asked before the wild's team goes out, in the frame every bracket
/// dialog wears (showBracketConfirm).
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
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: accent.withValues(alpha: 0.9),
          strokeWidth: 1.3,
        ),
        child: Container(
          color: palette.bg1,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'DEPLOY TEAM?',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: palette.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Creatures in the wild are unique and will not be there '
                'again after leaving.',
                style: bracketText(
                  context,
                  14,
                  palette.ink.withValues(alpha: 0.9),
                ),
              ),
              if (_shortHanded) ...[
                const SizedBox(height: 12),
                Text(
                  'Deploying $partyCount of $maxSize. You have enough '
                  'creatures to fill the team.',
                  style: bracketText(
                    context,
                    12.5,
                    accent,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: BracketButton(
                      label: 'CANCEL',
                      primary: false,
                      height: 42,
                      palette: palette,
                      accent: accent,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context, false);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BracketButton(
                      label: 'DEPLOY',
                      height: 42,
                      palette: palette,
                      accent: accent,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context, true);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
