import 'package:flutter/material.dart';

Color getTintingTextColor(String tinting) {
  switch (tinting) {
    case 'warm':
      return Colors.red.shade700;
    case 'cool':
      return Colors.cyan.shade50;
    case 'vibrant':
      return Colors.purple.shade50;
    case 'pale':
      return Colors.grey.shade50;
    default:
      return Colors.grey.shade50;
  }
}

Color getSizeColor(String size) {
  switch (size) {
    case 'tiny':
      return Colors.pink;
    case 'small':
      return Colors.blue;
    case 'normal':
      return Colors.black;
    case 'large':
      return Colors.green;
    case 'giant':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

Color getSizeTextColor(String size) {
  switch (size) {
    case 'tiny':
      return Colors.pink.shade700;
    case 'small':
      return Colors.blue.shade700;
    case 'normal':
      return Colors.grey.shade700;
    case 'large':
      return Colors.green.shade700;
    case 'giant':
      return Colors.orange.shade700;
    default:
      return Colors.grey.shade700;
  }
}

Color getTintingColor(String tinting) {
  switch (tinting) {
    case 'warm':
      return Colors.red.shade50;
    case 'cool':
      return Colors.cyan.shade700;
    case 'vibrant':
      return Colors.purple.shade700;
    case 'pale':
      return Colors.grey.shade600;
    default:
      return Colors.grey.shade700;
  }
}

IconData getGroupIcon(String groupBy) {
  switch (groupBy) {
    case 'Level':
      return Icons.trending_up_rounded;
    case 'Genetics':
      return Icons.auto_awesome_rounded;
    case 'Creation Date':
      return Icons.schedule_rounded;
    default:
      return Icons.group_work_rounded;
  }
}
