import 'package:alchemons/models/creature.dart';
import 'package:flutter/material.dart';

double scaleFromGenes(Genetics? g) {
  switch (g?.get('size')) {
    case 'tiny':
      return 0.75;
    case 'small':
      return 0.90;
    case 'large':
      return 1.15;
    case 'giant':
      return 1.30;
    default:
      return 1.00;
  }
}

double satFromGenes(Genetics? g) {
  switch (g?.get('tinting')) {
    case 'warm':
    case 'cool':
      return 1.10;
    case 'vibrant':
      return 1.40;
    case 'pale':
      return 0.60;
    case 'albino':
      return 0.0; // UPDATED: completely desaturated (will be overridden by albino matrix)
    default:
      return 1.00;
  }
}

double briFromGenes(Genetics? g) {
  switch (g?.get('tinting')) {
    case 'warm':
    case 'cool':
      return 1.05;
    case 'vibrant':
      return 1.10;
    case 'pale':
      return 1.20;
    case 'albino':
      return 1.45; // UPDATED: brighter for more white appearance
    default:
      return 1.00;
  }
}

double hueFromGenes(Genetics? g) {
  switch (g?.get('tinting')) {
    case 'warm':
      return 15;
    case 'cool':
      return -15;
    case 'albino':
      return 0; // Will be ignored anyway due to albino flag
    default:
      return 0;
  }
}

const Map<String, String> sizeLabels = {
  'tiny': 'Tiny',
  'small': 'Small',
  'normal': 'Normal',
  'large': 'Large',
  'giant': 'Giant',
};

const Map<String, String> tintLabels = {
  'pale': 'Diminished',
  'normal': 'Normal',
  'vibrant': 'Saturated',
  'warm': 'Thermal',
  'cool': 'Cryogenic',
  'albino': 'Albino',
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
  'albino': Icons.brightness_high_outlined,
};

String getStatDescriptor(double value, String statType) {
  // Scientific descriptors for each stat type
  const descriptors = {
    'speed': {
      'range1': 'Lethargic',
      'range2': 'Sluggish',
      'range3': 'Moderate',
      'range4': 'Agile',
      'range5': 'Exceptional',
      'perfect': 'Peak Velocity',
    },
    'intelligence': {
      'range1': 'Primitive',
      'range2': 'Limited Cognition',
      'range3': 'Average Intellect',
      'range4': 'Advanced Cognition',
      'range5': 'Superior Intellect',
      'perfect': 'Genius-Level',
    },
    'strength': {
      'range1': 'Feeble',
      'range2': 'Weak',
      'range3': 'Average Fortitude',
      'range4': 'Robust',
      'range5': 'Exceptional Power',
      'perfect': 'Peak Physical Form',
    },
    'beauty': {
      'range1': 'Unremarkable',
      'range2': 'Plain',
      'range3': 'Adequate Appeal',
      'range4': 'Striking',
      'range5': 'Extraordinary',
      'perfect': 'Flawless Phenotype',
    },
  };

  if (value == 10.0) {
    return descriptors[statType]!['perfect']!;
  } else if (value >= 8.0) {
    return descriptors[statType]!['range5']!;
  } else if (value >= 6.0) {
    return descriptors[statType]!['range4']!;
  } else if (value >= 4.0) {
    return descriptors[statType]!['range3']!;
  } else if (value >= 2.0) {
    return descriptors[statType]!['range2']!;
  } else {
    return descriptors[statType]!['range1']!;
  }
}
