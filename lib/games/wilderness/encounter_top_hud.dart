// The top band of a wild encounter: who you are looking at.
//
// It used to be three boxes fighting for the same strip of sky — a FIELD
// STATUS card, a rarity chip and a name — laid out with a guessed symmetric
// inset that squeezed the card to a sliver whenever the party strip was
// full. The status Row had no flexible child, so once it no longer fit the
// Spacer between its two labels collapsed to zero (FIELD STATUSSTABILITY) and
// the overflow painted outside the card, under the party strip.
//
// So the band owns the party strip too, and reserves the corners it cannot
// have: the Exit button's on the left, the strip's on the right. The identity
// sits in what remains, and drops below the strip when what remains is too
// narrow to read. The geometry is pinned by encounter_top_hud_test.dart.

import 'dart:async';
import 'dart:math';

import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

// Wild encounters render over dark scene backdrops — always dark.
const _kPalette = BracketPalette.dark;

/// Inset of the whole band from the safe-area edge. Matches the padding
/// `WildernessControls` puts around the Exit button, so the two line up.
const double kEncounterHudEdgePad = 8;

/// Horizontal room kept clear for the Exit button in the opposite corner:
/// its 66px minimum width plus the same 8px padding.
const double kEncounterHudLeftGutter = 74;

/// Breathing room between the identity block and whatever it sits beside.
const double kEncounterHudGap = 12;

/// Below this the identity is not worth reading beside the party strip, so it
/// goes under it instead. A rarity chip and the Potential plate need it.
const double kEncounterIdentityMinWidth = 220;

/// The identity never spreads wider than this even on a tablet — a name
/// tracked across 900px stops reading as a label.
const double kEncounterIdentityMaxWidth = 340;

const double kPartyCardWidth = 56;
const double kPartyCardGap = 6;
const double kPartyStripPadding = 8;

/// Width of the party strip holding [count] members.
///
/// The strip is a fixed-size card grid, so the band can reserve its corner
/// without measuring it — and the strip is then forced to exactly this width,
/// which is what stops the reservation and the reality drifting apart.
double partyStripWidthFor(int count) => count == 0
    ? 0
    : count * kPartyCardWidth +
          (count - 1) * kPartyCardGap +
          kPartyStripPadding * 2;

/// Room for the tutorial callout that sits above the strip.
///
/// The callout is wider than one card and the strip's box is sized to its
/// cards, so without this the words are scaled down to nothing on a
/// one-member party — which is exactly when the tutorial runs.
const double kPartyStripCalloutWidth = 184;

/// The gutter to reserve for [count] members, widened while [withCallout]
/// so the callout above them has somewhere to be.
double partyStripGutterFor(int count, {bool withCallout = false}) {
  final strip = partyStripWidthFor(count);
  if (!withCallout || strip == 0) return strip;
  return strip > kPartyStripCalloutWidth ? strip : kPartyStripCalloutWidth;
}

/// One of the wild specimen's four Potential ratings.
typedef WildPotentialReading = ({String label, double value});

/// The encounter's top band. Give it the party strip; it decides where the
/// strip and the identity can both live at this width.
class WildEncounterTopHud extends StatelessWidget {
  const WildEncounterTopHud({
    super.key,
    required this.name,
    required this.rarity,
    this.showRarityBadge = true,
    this.potentials,
    this.passingPotential,
    this.partyStrip,
    this.partyStripWidth = 0,
    this.leftGutter = kEncounterHudLeftGutter,
    this.opacity = 1,
    this.animateName = true,
    this.dossier = false,
  });

  final String name;
  final String rarity;
  final bool showRarityBadge;

  /// The four Potential ratings, or null when the Wild Potential Scanner is
  /// still locked — in which case the readout is absent, not blanked.
  final List<WildPotentialReading>? potentials;

  /// Index into [potentials] of the one a fusion is certain to pass on — the
  /// wild's highest — marked in gold. Null when this encounter cannot fuse.
  final int? passingPotential;

  final Widget? partyStrip;
  final double partyStripWidth;
  final double leftGutter;
  final double opacity;

  /// Off in tests and wherever the type-in would only cost frames.
  final bool animateName;

  /// Pinned to the top-left and left-aligned, with a smaller name, so the
  /// middle of the frame belongs to the creatures. Hosts that stage their
  /// own specimens (the space encounter) use this; the wilderness keeps the
  /// centred title.
  final bool dossier;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final strip = partyStrip;
        final reserved = strip == null
            ? 0.0
            : partyStripWidth + kEncounterHudGap;
        final lane = constraints.maxWidth - leftGutter - reserved;
        final abreast = lane >= kEncounterIdentityMinWidth;

        final identity = Opacity(
          opacity: opacity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kEncounterIdentityMaxWidth,
            ),
            child: _EncounterIdentity(
              name: name,
              rarity: rarity,
              showRarityBadge: showRarityBadge,
              potentials: potentials,
              passingPotential: passingPotential,
              animateName: animateName,
              dossier: dossier,
            ),
          ),
        );

        if (abreast) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: leftGutter),
              Expanded(
                child: dossier
                    ? Align(alignment: Alignment.topLeft, child: identity)
                    : Center(child: identity),
              ),
              if (strip != null) ...[
                const SizedBox(width: kEncounterHudGap),
                SizedBox(width: partyStripWidth, child: strip),
              ],
            ],
          );
        }

        // Nothing fits beside the strip at this width. The strip keeps the
        // corner and the identity drops under it — which also puts it below
        // the Exit button, so it no longer needs the left gutter.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (strip != null) ...[
              Align(
                alignment: Alignment.topRight,
                child: SizedBox(width: partyStripWidth, child: strip),
              ),
              const SizedBox(height: kEncounterHudGap),
            ],
            Padding(
              padding: EdgeInsets.only(left: strip == null ? leftGutter : 0),
              child: dossier
                  ? Align(alignment: Alignment.topLeft, child: identity)
                  : Center(child: identity),
            ),
          ],
        );
      },
    );
  }
}

/// Rarity and the Potential plate, and the name under them. Nothing else: a
/// status slate under the name ("X locked in.", the fusion stability) only
/// narrated what the party strip and the buttons already showed.
class _EncounterIdentity extends StatelessWidget {
  const _EncounterIdentity({
    required this.name,
    required this.rarity,
    required this.showRarityBadge,
    required this.potentials,
    required this.animateName,
    this.passingPotential,
    this.dossier = false,
  });

  final bool dossier;
  final String name;
  final String rarity;
  final bool showRarityBadge;
  final List<WildPotentialReading>? potentials;
  final int? passingPotential;
  final bool animateName;

  Color get _rarityColor {
    switch (rarity.toLowerCase()) {
      case 'uncommon':
        return const Color(0xFF34D399);
      case 'rare':
        return const Color(0xFF60A5FA);
      case 'epic':
        return const Color(0xFFA855F7);
      case 'legendary':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF9AA0AC);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readings = potentials;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: dossier
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        // Rarity and the Potential plate share one line: the chip left most
        // of it empty, and a full row of four spread-out cells inside the
        // slate cost the band a whole extra line. On a lane too narrow for
        // both the plate wraps under the chip rather than squeezing it.
        if (showRarityBadge || readings != null) ...[
          Wrap(
            alignment: dossier ? WrapAlignment.start : WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              if (showRarityBadge)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _rarityColor.withValues(alpha: 0.16),
                    border: Border(
                      left: BorderSide(color: _rarityColor, width: 2),
                    ),
                  ),
                  child: Text(
                    rarity.toUpperCase(),
                    style: bracketText(
                      context,
                      11,
                      _rarityColor,
                      weight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              if (readings != null)
                _PotentialReadout(
                  readings: readings,
                  passing: passingPotential,
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        _DigitalAnimatedText(
          text: name.toUpperCase(),
          animate: animateName,
          style: TextStyle(
            color: _kPalette.ink,
            fontSize: dossier ? 21 : 30,
            fontWeight: FontWeight.w900,
            letterSpacing: dossier ? 2.2 : 3.0,
            shadows: [
              const Shadow(
                color: Colors.black87,
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
              Shadow(
                color: _rarityColor.withValues(alpha: 0.34),
                blurRadius: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The four Potential ratings as one tight plate beside the rarity chip —
/// sized to its figures, not stretched across the slate.
class _PotentialReadout extends StatelessWidget {
  const _PotentialReadout({required this.readings, this.passing});

  final List<WildPotentialReading> readings;

  /// The reading a fusion is certain to pass on, if any.
  final int? passing;

  static const _accent = Color(0xFF60A5FA);

  /// The gold of the passing Potential: the same amber the rest of the
  /// encounter chrome uses for what is earned.
  static const _gold = Color(0xFFE4C16A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      // Opaque: the figures read against open sky. No accent
      // edge — the rarity chip beside it owns the line's colour.
      color: _kPalette.bg0.withValues(alpha: 0.86),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          for (var i = 0; i < readings.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Text(
              readings[i].label,
              style: bracketText(
                context,
                8.5,
                i == passing ? _gold : _kPalette.muted,
                weight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              readings[i].value.round().clamp(1, 100).toString(),
              style: bracketText(
                context,
                11,
                i == passing ? _gold : _accent,
                weight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Glitchy type-in for the specimen designation.
class _DigitalAnimatedText extends StatefulWidget {
  const _DigitalAnimatedText({
    required this.text,
    required this.style,
    this.animate = true,
  });

  final String text;
  final TextStyle style;
  final bool animate;

  /// Long enough to read as a scan, short enough that the name is settled
  /// before anyone reaches for a button.
  static const _typeIn = Duration(milliseconds: 900);

  @override
  State<_DigitalAnimatedText> createState() => _DigitalAnimatedTextState();
}

class _DigitalAnimatedTextState extends State<_DigitalAnimatedText> {
  String _displayText = '';
  Timer? _timer;
  int _currentIndex = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    if (widget.animate) _startAnimation();
  }

  void _startAnimation() {
    final interval =
        _DigitalAnimatedText._typeIn.inMilliseconds ~/ widget.text.length;

    _timer = Timer.periodic(
      Duration(milliseconds: interval > 0 ? interval : 1),
      (timer) {
        if (_currentIndex < widget.text.length) {
          _displayText = widget.text.substring(0, _currentIndex + 1);
          // A few random letters trailing the cursor sell the scan.
          final glitchLength = _random.nextInt(3) + 1;
          for (int i = 0; i < glitchLength; i++) {
            _displayText += String.fromCharCode(_random.nextInt(26) + 65);
          }
          _currentIndex++;
        } else {
          _displayText = widget.text;
          timer.cancel();
        }
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settled = !widget.animate || _currentIndex >= widget.text.length;
    return Text(
      settled ? widget.text : _displayText,
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
