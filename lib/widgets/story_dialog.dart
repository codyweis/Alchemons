// lib/widgets/story_dialog.dart
//
// THE ONE DIALOG THE GAME SPEAKS IN. Story beats, tutorial prompts and in-world
// notices all open here: the bracket confirm's frame (bracket_controls.dart)
// on the dark ground, a rule of grains under the title, and the text set down
// whole — no typewriter. It replaced two older copies (SystemDialog's black
// box and LandscapeDialog's glowing one), each with a Timer that rebuilt the
// dialog once per character.
//
// A dialog can hold several [StoryBeat]s. They page in place (NEXT, then the
// last page's own button) so a pair of story cards that used to open one
// after the other is one dialog with two pages.
//
// Always the dark palette: these open over the wilderness, open space and the
// lab alike, and the story's voice is the same in all of them.

import 'dart:math' as math;

import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum StoryDialogKind { info, success, warning, danger }

/// One page of a [StoryDialog].
class StoryBeat {
  const StoryBeat({required this.title, required this.message, this.voice});

  final String title;
  final String message;

  /// A line in the story's own voice, set apart under [message] in the
  /// opening's italic serif. When [message] is empty it is the whole page.
  final String? voice;
}

/// The accent a kind of dialog is framed in, readable on the dark ground.
Color storyDialogAccent(StoryDialogKind kind) => switch (kind) {
  StoryDialogKind.info => const Color(0xFFE0B068),
  StoryDialogKind.success => const Color(0xFF8FCB8F),
  StoryDialogKind.warning => const Color(0xFFE8C46A),
  StoryDialogKind.danger => const Color(0xFFE57373),
};

/// Opens [beats] as one dialog. Resolves true for the last page's primary
/// button, false for the secondary one, null if dismissed by the barrier.
Future<bool?> showStoryDialog(
  BuildContext context, {
  required List<StoryBeat> beats,
  StoryDialogKind kind = StoryDialogKind.info,
  @Deprecated('Story dialogs no longer show an icon; drop the argument')
  IconData? icon,
  String primaryLabel = 'CONTINUE',
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
  bool barrierDismissible = false,
}) {
  assert(beats.isNotEmpty);
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => StoryDialog(
      beats: beats,
      kind: kind,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
    ),
  );
}

class StoryDialog extends StatefulWidget {
  const StoryDialog({
    super.key,
    required this.beats,
    this.kind = StoryDialogKind.info,
    this.icon,
    this.primaryLabel = 'CONTINUE',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final List<StoryBeat> beats;
  final StoryDialogKind kind;

  /// Never drawn; kept until the last caller drops it.
  @Deprecated('Story dialogs no longer show an icon; drop the argument')
  final IconData? icon;

  /// The last page's button; earlier pages say NEXT.
  final String primaryLabel;
  final VoidCallback? onPrimary;

  /// Shown on the last page only, beside [primaryLabel].
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  State<StoryDialog> createState() => _StoryDialogState();
}

class _StoryDialogState extends State<StoryDialog> {
  int _page = 0;

  bool get _last => _page >= widget.beats.length - 1;

  void _primary() {
    if (!_last) {
      setState(() => _page++);
      return;
    }
    Navigator.of(context).pop(true);
    widget.onPrimary?.call();
  }

  void _secondary() {
    Navigator.of(context).pop(false);
    widget.onSecondary?.call();
  }

  /// Side by side, or stacked (primary on top) when the two labels would
  /// not fit next to each other on a phone.
  Widget _buttons(BracketPalette palette, Color accent) {
    final primary = BracketButton(
      label: _last ? widget.primaryLabel : 'NEXT',
      height: 42,
      palette: palette,
      accent: accent,
      onTap: _primary,
    );
    final secondaryLabel = _last ? widget.secondaryLabel : null;
    if (secondaryLabel == null) return primary;
    final secondary = BracketButton(
      label: secondaryLabel,
      primary: false,
      height: 42,
      palette: palette,
      accent: accent,
      onTap: _secondary,
    );
    final longest = math.max(widget.primaryLabel.length, secondaryLabel.length);
    if (longest > 11) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [primary, const SizedBox(height: 10), secondary],
      );
    }
    return Row(
      children: [
        Expanded(child: secondary),
        const SizedBox(width: 10),
        Expanded(child: primary),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const palette = BracketPalette.dark;
    final accent = storyDialogAccent(widget.kind);
    final media = MediaQuery.of(context);
    final landscape = media.size.width > media.size.height;
    final beat = widget.beats[_page];
    final count = widget.beats.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: landscape ? 40 : 24,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: landscape ? 560 : 420,
          maxHeight: media.size.height * (landscape ? 0.82 : 0.75),
        ),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: accent.withValues(alpha: 0.9),
            bracketSize: 14,
            strokeWidth: 1.3,
          ),
          child: Container(
            color: palette.bg1,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, if (current != null) current],
                    ),
                    child: _BeatBody(
                      key: ValueKey(_page),
                      beat: beat,
                      accent: accent,
                      palette: palette,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (count > 1) ...[
                  _PageGrains(
                    count: count,
                    current: _page,
                    accent: accent,
                    palette: palette,
                  ),
                  const SizedBox(height: 12),
                ],
                _buttons(palette, accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BeatBody extends StatelessWidget {
  const _BeatBody({
    super.key,
    required this.beat,
    required this.accent,
    required this.palette,
  });

  final StoryBeat beat;
  final Color accent;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    final voice = beat.voice;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A page with no title is a line of the story on its own.
          if (beat.title.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    beat.title.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: palette.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 6,
              child: CustomPaint(painter: _GrainRulePainter(accent)),
            ),
            const SizedBox(height: 14),
          ],
          if (beat.message.isNotEmpty)
            Text(
              beat.message,
              style: bracketText(
                context,
                14,
                palette.ink.withValues(alpha: 0.9),
              ).copyWith(height: 1.45),
            ),
          if (voice != null) ...[
            if (beat.message.isNotEmpty) const SizedBox(height: 14),
            Text(
              voice,
              textAlign: TextAlign.center,
              style: GoogleFonts.crimsonText(
                fontSize: 19,
                height: 1.45,
                color: palette.ink,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A rule of grains: dense and bright at the left, thinning out to the
/// right, the same scatter every time. Painted once.
class _GrainRulePainter extends CustomPainter {
  _GrainRulePainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(11);
    final paint = Paint();
    final w = math.min(size.width, 220.0);
    for (var i = 0; i < 70; i++) {
      final t = math.pow(rng.nextDouble(), 1.6).toDouble();
      final x = t * w;
      final y = size.height / 2 + (rng.nextDouble() - 0.5) * size.height;
      final r = 0.5 + rng.nextDouble() * 0.9 * (1 - t);
      paint.color = accent.withValues(alpha: 0.85 * (1 - t) + 0.1);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainRulePainter old) => old.accent != accent;
}

/// Which page: one grain per page, the current one lit.
class _PageGrains extends StatelessWidget {
  const _PageGrains({
    required this.count,
    required this.current,
    required this.accent,
    required this.palette,
  });

  final int count;
  final int current;
  final Color accent;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: i == current ? 6 : 4,
            height: i == current ? 6 : 4,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current ? accent : palette.line,
            ),
          ),
      ],
    );
  }
}
