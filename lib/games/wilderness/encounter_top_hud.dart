// The top band of a wild encounter: who you are looking at, and how the
// field is behaving.
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

import 'package:alchemons/constants/design_tokens.dart';
import 'package:alchemons/widgets/app_icons.dart';
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
/// goes under it instead. A rarity chip plus four potential cells needs it.
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

/// One of the wild specimen's four Potential ratings.
typedef WildPotentialReading = ({String label, double value});

/// Accent and icon for the current field status line.
class EncounterStatusStyle {
  final Color accent;
  final IconData icon;

  const EncounterStatusStyle({required this.accent, required this.icon});

  static const _danger = Color(0xFFC0392B);
  static const _amber = Color(0xFFE4C16A);
  static const _success = Color(0xFF22C55E);
  static const _teal = Color(0xFF5BC8E8);

  factory EncounterStatusStyle.resolve(String status) {
    final normalized = status.toLowerCase();

    if (normalized.contains('failed') ||
        normalized.contains('error') ||
        normalized.contains('lost')) {
      return const EncounterStatusStyle(
        accent: _danger,
        icon: AppIcons.warning_amber_rounded,
      );
    }
    if (normalized.contains('research') ||
        normalized.contains('stamina') ||
        normalized.contains('capacity')) {
      return const EncounterStatusStyle(
        accent: _amber,
        icon: AppIcons.bolt_rounded,
      );
    }
    if (normalized.contains('complete') ||
        normalized.contains('sent to cultivations') ||
        normalized.contains('transferred')) {
      return const EncounterStatusStyle(
        accent: _success,
        icon: AppIcons.check_circle_rounded,
      );
    }
    if (normalized.contains('calibrating') ||
        normalized.contains('select') ||
        normalized.contains('choose') ||
        normalized.contains('secure')) {
      return const EncounterStatusStyle(
        accent: _teal,
        icon: AppIcons.tune_rounded,
      );
    }
    return const EncounterStatusStyle(
      accent: _amber,
      icon: AppIcons.auto_awesome_rounded,
    );
  }
}

/// The encounter's top band. Give it the party strip; it decides where the
/// strip and the identity can both live at this width.
class WildEncounterTopHud extends StatelessWidget {
  const WildEncounterTopHud({
    super.key,
    required this.name,
    required this.rarity,
    required this.status,
    this.showRarityBadge = true,
    this.breedChance,
    this.potentials,
    this.partyStrip,
    this.partyStripWidth = 0,
    this.leftGutter = kEncounterHudLeftGutter,
    this.opacity = 1,
    this.animateName = true,
  });

  final String name;
  final String rarity;
  final String status;
  final bool showRarityBadge;

  /// Wild-fusion stability, 0..1. Null when this encounter cannot be fused.
  final double? breedChance;

  /// The four Potential ratings, or null when the Wild Potential Scanner is
  /// still locked — in which case the readout is absent, not blanked.
  final List<WildPotentialReading>? potentials;

  final Widget? partyStrip;
  final double partyStripWidth;
  final double leftGutter;
  final double opacity;

  /// Off in tests and wherever the type-in would only cost frames.
  final bool animateName;

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
              status: status,
              showRarityBadge: showRarityBadge,
              breedChance: breedChance,
              potentials: potentials,
              animateName: animateName,
            ),
          ),
        );

        if (abreast) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: leftGutter),
              Expanded(child: Center(child: identity)),
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
              child: Center(child: identity),
            ),
          ],
        );
      },
    );
  }
}

/// Rarity, name, and — under them — one quiet slate carrying the readout and
/// the field status. One frame, not three.
class _EncounterIdentity extends StatelessWidget {
  const _EncounterIdentity({
    required this.name,
    required this.rarity,
    required this.status,
    required this.showRarityBadge,
    required this.breedChance,
    required this.potentials,
    required this.animateName,
  });

  final String name;
  final String rarity;
  final String status;
  final bool showRarityBadge;
  final double? breedChance;
  final List<WildPotentialReading>? potentials;
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
    final statusStyle = EncounterStatusStyle.resolve(status);
    final readings = potentials;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showRarityBadge) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _rarityColor.withValues(alpha: 0.16),
              border: Border(left: BorderSide(color: _rarityColor, width: 2)),
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
          const SizedBox(height: 4),
        ],
        _DigitalAnimatedText(
          text: name.toUpperCase(),
          animate: animateName,
          style: TextStyle(
            color: _kPalette.ink,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
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
        const SizedBox(height: AppSpace.sm),
        CustomPaint(
          painter: BracketFramePainter(
            color: statusStyle.accent.withValues(alpha: 0.7),
            bracketSize: 8,
            strokeWidth: 1.0,
          ),
          child: Container(
            // Opaque, not a wash: this reads against open sky.
            color: _kPalette.bg0.withValues(alpha: 0.88),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (readings != null) ...[
                  _PotentialReadout(readings: readings),
                  const SizedBox(height: 5),
                  Container(height: 1, color: _kPalette.lineSoft),
                  const SizedBox(height: 5),
                ],
                _StatusLine(
                  style: statusStyle,
                  status: status,
                  breedChance: breedChance,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The four Potential ratings, in equal columns so the numbers line up
/// however wide the slate is.
class _PotentialReadout extends StatelessWidget {
  const _PotentialReadout({required this.readings});

  final List<WildPotentialReading> readings;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF60A5FA);
    return Row(
      children: [
        for (var i = 0; i < readings.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 14,
              color: _kPalette.lineSoft,
              margin: const EdgeInsets.symmetric(horizontal: 2),
            ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    readings[i].label,
                    style: bracketText(
                      context,
                      9,
                      _kPalette.muted,
                      weight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    readings[i].value.round().clamp(1, 100).toString(),
                    style: bracketText(
                      context,
                      12,
                      accent,
                      weight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Chrome: what the field is doing, and how firmly it is holding.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.style,
    required this.status,
    required this.breedChance,
  });

  final EncounterStatusStyle style;
  final String status;
  final double? breedChance;

  @override
  Widget build(BuildContext context) {
    final chance = breedChance;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(style.icon, color: style.accent, size: 13),
        const SizedBox(width: 6),
        // Flexible, so a long status ellipsises instead of shoving the
        // stability figure out of the slate.
        Expanded(
          child: Text(
            status,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: bracketText(
              context,
              11,
              _kPalette.muted,
              weight: FontWeight.w600,
            ),
            strutStyle: const StrutStyle(height: 1.25),
          ),
        ),
        if (chance != null) ...[
          const SizedBox(width: AppSpace.sm),
          Text(
            'STAB',
            style: bracketText(
              context,
              8.5,
              _kPalette.muted,
              weight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '${(chance * 100).toStringAsFixed(1)}%',
            style: bracketText(
              context,
              12,
              const Color(0xFF22C55E),
              weight: FontWeight.w800,
            ),
          ),
        ],
      ],
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
