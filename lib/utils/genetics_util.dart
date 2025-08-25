import 'package:alchemons/models/creature.dart';
import 'package:flutter/material.dart';

double scaleFromGenes(Genetics? g) {
  switch (g?.get('size')) {
    case 'tiny':
      return 0.75;
    case 'small':
      return 0.9;
    case 'large':
      return 1.15;
    case 'giant':
      return 1.3;
    default:
      return 1.0;
  }
}

double satFromGenes(Genetics? g) {
  switch (g?.get('tinting')) {
    case 'warm':
    case 'cool':
      return 1.1;
    case 'vibrant':
      return 1.4;
    case 'pale':
      return 0.6;
    default:
      return 1.0;
  }
}

double briFromGenes(Genetics? g) {
  switch (g?.get('tinting')) {
    case 'warm':
    case 'cool':
      return 1.05;
    case 'vibrant':
      return 1.1;
    case 'pale':
      return 1.2;
    default:
      return 1.0;
  }
}

double hueFromGenes(Genetics? g) {
  switch (g?.get('tinting')) {
    case 'warm':
      return 15;
    case 'cool':
      return -15;
    default:
      return 0;
  }
}

const Map<String, String> tintLabels = {
  'normal': 'Normal',
  'warm': 'Thermal',
  'cool': 'Cryogenic',
  'vibrant': 'Saturated',
  'pale': 'Diminished',
};

const Map<String, String> sizeLabels = {
  'tiny': 'Micro',
  'small': 'Compact',
  'normal': 'Standard',
  'large': 'Enhanced',
  'giant': 'Gigantic',
};

const Map<String, IconData> sizeIcons = {
  'tiny': Icons.radio_button_unchecked,
  'small': Icons.circle_outlined,
  'normal': Icons.circle,
  'large': Icons.adjust,
  'giant': Icons.circle_rounded,
};

const Map<String, IconData> tintIcons = {
  'normal': Icons.palette_outlined,
  'warm': Icons.thermostat_rounded,
  'cool': Icons.ac_unit_outlined,
  'vibrant': Icons.auto_awesome,
  'pale': Icons.blur_on,
};
