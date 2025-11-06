import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StaminaInlineRow extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final String instanceId;
  const StaminaInlineRow({
    required this.theme,
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
            child: Text(
              label,
              style: TextStyle(
                color: theme.text.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
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
  final FactionTheme theme;
  final String label;
  final double value;

  const StatBarRow({
    required this.theme,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final descriptor = getStatDescriptor(value, label.toLowerCase());
    final fill = (value / 5.0).clamp(0.0, 1.0);
    final isMaxed = value == 5.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: TextStyle(
                    color: theme.text.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.07),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: fill,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isMaxed
                                    ? [Colors.amber, Colors.amber.shade600]
                                    : [
                                        theme.primary,
                                        theme.secondary.withOpacity(.7),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(4),
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
                        color: isMaxed
                            ? Colors.amber.withOpacity(.2)
                            : theme.primary.withOpacity(.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isMaxed
                              ? Colors.amber.withOpacity(.4)
                              : theme.primary.withOpacity(.3),
                        ),
                      ),
                      child: Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          color: isMaxed ? Colors.amber : theme.primary,
                          fontSize: 11,
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
                color: isMaxed
                    ? Colors.amber.withOpacity(.9)
                    : const Color(0xFF9AA6B2),
                fontSize: 10,
                fontStyle: FontStyle.italic,
                fontWeight: isMaxed ? FontWeight.w600 : FontWeight.normal,
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
    final vc = valueColor ?? const Color(0xFFE8EAED);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: vc,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(valueText, style: TextStyle(color: vc, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
