import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StaminaInlineRow extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final String label;
  final String instanceId;
  const StaminaInlineRow({
    this.theme,
    required this.label,
    required this.instanceId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label.toUpperCase(), style: FT.label),
          ),
          Expanded(
            child: StaminaBadge(instanceId: instanceId, showCountdown: true),
          ),
        ],
      ),
    );
  }
}

class StatBarRow extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final String label;
  final double value;

  const StatBarRow({this.theme, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final descriptor = getStatDescriptor(value, label.toLowerCase());
    final fill = (value / 5.0).clamp(0.0, 1.0);
    final isMaxed = value == 5.0;
    const barColor = FC.amber;
    final dimColor = FC.amberDim;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(label.toUpperCase(), style: FT.label),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: FC.bg3,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: FC.borderDim),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: fill,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isMaxed
                                    ? [FC.amberGlow, FC.amber]
                                    : [barColor, dimColor],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isMaxed ? FC.amber.withOpacity(.18) : FC.bg3,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: isMaxed
                              ? FC.amber.withOpacity(.5)
                              : FC.borderDim,
                        ),
                      ),
                      child: Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: isMaxed ? FC.amberGlow : FC.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 100),
            child: Text(
              descriptor,
              style: TextStyle(
                fontFamily: 'monospace',
                color: isMaxed ? FC.amberBright : FC.textMuted,
                fontSize: 9,
                fontStyle: FontStyle.italic,
                fontWeight: isMaxed ? FontWeight.w600 : FontWeight.normal,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData categoryIcon(String category) {
  switch (category) {
    case 'familyLineage':
      return Icons.family_restroom;
    case 'elementalType':
      return Icons.whatshot;
    case 'genetics':
      return Icons.biotech;
    case 'nature':
      return Icons.psychology;
    case 'special':
      return Icons.star;
    default:
      return Icons.info;
  }
}

class LabeledInlineValue extends StatelessWidget {
  final String label;
  final String valueText;
  final Color? valueColor;

  const LabeledInlineValue({
    required this.label,
    required this.valueText,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label.toUpperCase(), style: FT.label),
          ),
          Expanded(
            child: Text(
              valueText,
              style: FT.body.copyWith(
                color: valueColor ?? FC.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
