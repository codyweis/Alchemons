import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:flutter/material.dart';

class StaminaInlineRow extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final String label;
  final String instanceId;
  const StaminaInlineRow({super.key, 
    this.theme,
    required this.label,
    required this.instanceId,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label.toUpperCase(), style: ft.label),
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

  const StatBarRow({super.key, this.theme, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    final descriptor = getStatDescriptor(value, label.toLowerCase());
    final fill = (value / 5.0).clamp(0.0, 1.0);
    final isMaxed = value == 5.0;
    final barColor = fc.amber;
    final dimColor = fc.amberDim;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(label.toUpperCase(), style: ft.label),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: fc.bg3,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: fc.borderDim),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: fill,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isMaxed
                                    ? [fc.amberGlow, fc.amber]
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
                        color: isMaxed ? fc.amber.withValues(alpha: .18) : fc.bg3,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: isMaxed
                              ? fc.amber.withValues(alpha: .5)
                              : fc.borderDim,
                        ),
                      ),
                      child: Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: isMaxed ? fc.amberGlow : fc.textPrimary,
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
                color: isMaxed ? fc.amberBright : fc.textMuted,
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

  const LabeledInlineValue({super.key, 
    required this.label,
    required this.valueText,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label.toUpperCase(), style: ft.label),
          ),
          Expanded(
            child: Text(
              valueText,
              style: ft.body.copyWith(
                color: valueColor ?? fc.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
