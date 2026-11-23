// lib/screens/friends/friends_screen.dart
//
// FRIENDS, every one: ALL from the profile's row of planets opens it. The
// same panel as the profile's (friends_panel.dart), with the planets three
// across instead of one row, so the page holds as many as the player has
// (up to FriendService.maxFriends).

import 'package:alchemons/screens/friends/friends_panel.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const FriendsScreen());

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: palette.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 10, 16, 0),
            child: Row(
              children: [
                BracketIconButton(
                  icon: AppIcons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                  palette: palette,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'FRIENDS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: palette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 40),
              child: ColoredBox(
                color: palette.bg1,
                child: FriendsPanel(
                  palette: palette,
                  accent: accent,
                  all: true,
                  // Only reached signed in; signed out on the way, back
                  // to the profile, which has the sign-in.
                  onSignIn: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
