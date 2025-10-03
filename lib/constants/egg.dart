import 'package:flutter/material.dart';

class EggPalette {
  final Color shell; // main shell body
  final Color cracks; // crack strokes
  final Color glow; // aura/highlight
  final Color particle; // burst particles if present in Lottie
  const EggPalette({
    required this.shell,
    required this.cracks,
    required this.glow,
    required this.particle,
  });
}

const _neutral = EggPalette(
  shell: Color(0xFF94A3B8), // slate 400-ish
  cracks: Color(0xFF475569), // slate 600
  glow: Color(0xFFCBD5E1), // slate 300
  particle: Color(0xFF64748B), // slate 500
);

const Map<String, EggPalette> kEggPaletteByElement = {
  // base 4
  'Fire': EggPalette(
    shell: Color.fromARGB(255, 255, 126, 87),
    cracks: Color(0xFF8C2F17),
    glow: Color(0xFFFFB17A),
    particle: Color(0xFFFF7A45),
  ),
  'Water': EggPalette(
    shell: Color.fromARGB(255, 21, 116, 161),
    cracks: Color(0xFF075985),
    glow: Color(0xFF7DD3FC),
    particle: Color(0xFF38BDF8),
  ),
  'Earth': EggPalette(
    shell: Color.fromARGB(255, 148, 80, 43),
    cracks: Color(0xFF4E2A15),
    glow: Color(0xFFE7C9B0),
    particle: Color(0xFFB45309),
  ),
  'Air': EggPalette(
    shell: Color.fromARGB(255, 206, 218, 177),
    cracks: Color(0xFF155E75),
    glow: Color(0xFFA5F3FC),
    particle: Color(0xFF67E8F9),
  ),
  // advanced
  'Steam': EggPalette(
    shell: Color.fromARGB(255, 108, 131, 142),
    cracks: Color(0xFF0E7490),
    glow: Color(0xFFFCA5A5),
    particle: Color(0xFF93C5FD),
  ),
  'Lava': EggPalette(
    shell: Color.fromARGB(255, 99, 28, 28),
    cracks: Color(0xFF111827),
    glow: Color(0xFFF97316),
    particle: Color(0xFFFB923C),
  ),
  'Lightning': EggPalette(
    shell: Color.fromARGB(255, 227, 179, 37),
    cracks: Color(0xFF78350F),
    glow: Color(0xFFFEF08A),
    particle: Color(0xFFFDE047),
  ),
  'Mud': EggPalette(
    shell: Color.fromARGB(255, 72, 50, 31),
    cracks: Color(0xFF3F2A16),
    glow: Color(0xFFB08968),
    particle: Color(0xFF8D6E63),
  ),
  'Ice': EggPalette(
    shell: Color.fromARGB(255, 147, 232, 255),
    cracks: Color(0xFF1E3A8A),
    glow: Color(0xFFBAE6FD),
    particle: Color(0xFF93C5FD),
  ),
  'Dust': EggPalette(
    shell: Color.fromARGB(255, 214, 198, 172),
    cracks: Color(0xFF6B7280),
    glow: Color(0xFFF5F5F4),
    particle: Color(0xFFD6D3D1),
  ),
  'Crystal': EggPalette(
    shell: Color.fromARGB(255, 182, 174, 255),
    cracks: Color(0xFF6D28D9),
    glow: Color(0xFFE9D5FF),
    particle: Color(0xFFC4B5FD),
  ),
  'Plant': EggPalette(
    shell: Color.fromARGB(255, 118, 207, 130),
    cracks: Color(0xFF14532D),
    glow: Color(0xFFA7F3D0),
    particle: Color(0xFF86EFAC),
  ),
  'Poison': EggPalette(
    shell: Color.fromARGB(255, 71, 44, 190), // toxic green
    cracks: Color(0xFF064E3B),
    glow: Color(0xFFA7F3D0),
    particle: Color(0xFF34D399),
  ),
  'Spirit': EggPalette(
    shell: Color.fromARGB(255, 255, 255, 255),
    cracks: Color(0xFF4C1D95),
    glow: Color(0xFFE9D5FF),
    particle: Color(0xFFBEA9FF),
  ),
  'Dark': EggPalette(
    shell: Color(0xFF111827),
    cracks: Color(0xFF000000),
    glow: Color(0xFF4B5563),
    particle: Color(0xFF1F2937),
  ),
  'Light': EggPalette(
    shell: Color.fromARGB(255, 255, 241, 183),
    cracks: Color(0xFFB45309),
    glow: Color(0xFFFFF7ED),
    particle: Color(0xFFFCD34D),
  ),
  'Blood': EggPalette(
    shell: Color(0xFFB91C1C),
    cracks: Color(0xFF7F1D1D),
    glow: Color(0xFFFCA5A5),
    particle: Color(0xFFEF4444),
  ),
};

EggPalette paletteForElement(String name) =>
    kEggPaletteByElement[name] ?? _neutral;
