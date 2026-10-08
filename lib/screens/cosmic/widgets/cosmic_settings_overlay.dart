import 'package:flutter/material.dart';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';

/// The ship's settings in space: control toggles, developer jumps when the
/// tools are on, and the way out. A plain panel in the kit, toggles lit in
/// brass, LEAVE SPACE lit red.
class CosmicSettingsOverlay extends StatelessWidget {
  const CosmicSettingsOverlay({
    super.key,
    required this.joystickEnabled,
    required this.largeJoystickEnabled,
    required this.autoFireGunEnabled,
    required this.autoFireMissilesEnabled,
    required this.boostToggleEnabled,
    required this.onClose,
    required this.onLeaveSpace,
    required this.onToggleJoystick,
    required this.onToggleLargeJoystick,
    required this.onToggleAutoFireGun,
    required this.onToggleAutoFireMissiles,
    required this.onToggleBoostToggle,
    required this.onReplayPrologue,
    required this.onKinPortal,
  });

  final bool joystickEnabled;
  final bool largeJoystickEnabled;
  final bool autoFireGunEnabled;
  final bool autoFireMissilesEnabled;
  final bool boostToggleEnabled;
  final VoidCallback onClose;
  final VoidCallback onLeaveSpace;
  final ValueChanged<bool> onToggleJoystick;
  final ValueChanged<bool> onToggleLargeJoystick;
  final ValueChanged<bool> onToggleAutoFireGun;
  final ValueChanged<bool> onToggleAutoFireMissiles;
  final ValueChanged<bool> onToggleBoostToggle;

  /// Developer tool: replay THE FIRST CROSSING from here.
  final VoidCallback onReplayPrologue;

  /// Developer tool: jump into the Nexus pocket and its four Kin portals.
  final VoidCallback onKinPortal;

  static const _palette = BracketPalette.dark;
  static const _brass = Color(0xFFB89656);
  static const _dev = Color(0xFF7BE88C);

  @override
  Widget build(BuildContext context) {
    Widget divider() => Container(
      height: 1,
      margin: const EdgeInsets.only(left: 14),
      color: _palette.lineSoft,
    );
    Widget toggle(
      String title,
      String description,
      bool value,
      ValueChanged<bool> onChanged,
    ) => BracketToggleRow(
      title: title,
      description: description,
      value: value,
      onChanged: onChanged,
      palette: _palette,
      accent: _brass,
    );

    return Material(
      color: _palette.bg0.withValues(alpha: 0.82),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(onClose),
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: _palette.bg1,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'SHIP SETTINGS',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: _palette.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: context.soundAction(onClose),
                            icon: const Icon(AppIcons.close_rounded),
                            color: _palette.muted,
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ),
                    toggle(
                      'JOYSTICK',
                      'Show the movement stick on screen',
                      joystickEnabled,
                      onToggleJoystick,
                    ),
                    divider(),
                    toggle(
                      'LARGE JOYSTICK',
                      'Use the expanded movement pad',
                      largeJoystickEnabled,
                      onToggleLargeJoystick,
                    ),
                    divider(),
                    toggle(
                      'AUTO FIRE: TURRET',
                      'Off, hold the gun button to fire by hand',
                      autoFireGunEnabled,
                      onToggleAutoFireGun,
                    ),
                    divider(),
                    toggle(
                      'AUTO FIRE: MISSILES',
                      'Off, hold the missile button to fire by hand',
                      autoFireMissilesEnabled,
                      onToggleAutoFireMissiles,
                    ),
                    divider(),
                    toggle(
                      'BOOST TOGGLE',
                      'Tap once to lock boost on or off',
                      boostToggleEnabled,
                      onToggleBoostToggle,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (DebugSettingsService.toolsVisible) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 6, 2, 9),
                              child: Text(
                                'DEVELOPER',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: _dev.withValues(alpha: 0.8),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.4,
                                ),
                              ),
                            ),
                            BracketButton(
                              label: 'REPLAY: THE FIRST CROSSING',
                              primary: false,
                              height: 40,
                              palette: _palette,
                              accent: _dev,
                              onTap: onReplayPrologue,
                            ),
                            const SizedBox(height: 8),
                            BracketButton(
                              label: 'NEXUS: THE 4 KIN PORTALS',
                              primary: false,
                              height: 40,
                              palette: _palette,
                              accent: _dev,
                              onTap: onKinPortal,
                            ),
                            const SizedBox(height: 14),
                          ],
                          BracketButton(
                            label: 'LEAVE SPACE',
                            height: 44,
                            palette: _palette,
                            accent: kLeaveDangerAccent,
                            onTap: onLeaveSpace,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
