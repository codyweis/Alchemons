// lib/screens/friends/friends_panel.dart
//
// FRIENDS on the profile: the player's own code to give out, a way to enter
// someone else's, the requests waiting either way, and their friends' home
// planets — a tap on one opens that friend's page (friend_planet_screen.dart).
//
// Signed out, it only says what signing in would bring. Laid out as the
// profile's own rows are, inside its panel.

import 'dart:async';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/screens/friends/friend_planet_screen.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/trade_service.dart';
import 'package:alchemons/utils/app_scaffold_messenger.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/home_planet_view.dart';
import 'package:alchemons/widgets/notification_banner_system.dart'
    show HomeNoticeDot;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

TextStyle _mono(double size, Color color, {double spacing = 1.4}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: FontWeight.w800,
  letterSpacing: spacing,
  height: 1.2,
);

TextStyle _prose(BuildContext context, Color color, {double size = 12.5}) =>
    bracketText(context, size, color).copyWith(height: 1.4);

class FriendsPanel extends StatefulWidget {
  const FriendsPanel({
    super.key,
    required this.palette,
    required this.accent,
    required this.onSignIn,
  });

  final BracketPalette palette;
  final Color accent;

  /// Opens the account's sign-in (the profile's ACCOUNT has the rest).
  final VoidCallback onSignIn;

  @override
  State<FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends State<FriendsPanel> {
  /// The account the lists were last asked for, so signing in reads them.
  String? _askedFor;

  /// Watched for friends' dots while this shows.
  FriendService? _presence;

  BracketPalette get _p => widget.palette;

  @override
  void initState() {
    super.initState();
    _presence = context.read<FriendService?>()?..watchPresence();
  }

  @override
  void dispose() {
    _presence?.unwatchPresence();
    super.dispose();
  }

  void _maybeRefresh(FriendService friends, AccountService account) {
    final uid = friends.available ? account.user?.uid : null;
    if (uid == null || uid == _askedFor) return;
    _askedFor = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(friends.refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountService>();
    // Missing only where the app's providers are not all there (previews).
    final friends = context.watch<FriendService?>();
    if (friends != null) _maybeRefresh(friends, account);
    final rows = <Widget>[];
    if (!account.initialized) {
      rows.add(_row(title: 'FRIENDS', text: 'Loading account services…'));
    } else if (!account.isConfigured) {
      rows.add(
        _row(title: 'FRIENDS', text: 'Friends need an account to work.'),
      );
    } else if (!account.isSignedIn) {
      rows.add(
        _row(
          title: 'VISIT FRIENDS',
          text:
              "Visit friends' homes, and let them visit yours. The game "
              'plays the same without it.',
          below: BracketButton(
            label: 'SIGN IN TO ADD FRIENDS',
            height: 40,
            palette: _p,
            accent: widget.accent,
            onTap: widget.onSignIn,
          ),
        ),
      );
    } else if (friends == null) {
      rows.add(_row(title: 'FRIENDS', text: 'Friends are not available.'));
    } else {
      rows.addAll(_signedIn(friends));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Container(
              height: 1,
              margin: const EdgeInsets.only(left: 14),
              color: _p.lineSoft,
            ),
          rows[i],
        ],
      ],
    );
  }

  List<Widget> _signedIn(FriendService friends) {
    final code = friends.code;
    return [
      _row(
        title: 'YOUR CODE',
        text:
            'Give it to a friend. Once one of you accepts the other, you can '
            "both visit each other's homes.",
        trailing: code == null
            ? null
            : _quiet('COPY', () {
                unawaited(Clipboard.setData(ClipboardData(text: code)));
                HapticFeedback.selectionClick();
                showAppSnack('Code copied.', fallbackContext: context);
              }),
        below: Text(
          code ?? (friends.loading ? '…' : '—'),
          style: _mono(22, _p.ink, spacing: 4),
        ),
      ),
      _row(
        title: 'ADD A FRIEND',
        text: 'Enter their code.',
        trailing: BracketButton(
          label: 'ADD',
          height: 36,
          palette: _p,
          accent: widget.accent,
          enabled: code != null,
          onTap: () => _add(friends),
        ),
      ),
      if (friends.error != null)
        _row(
          title: 'FRIENDS',
          text: friends.error!,
          trailing: _quiet('RETRY', () => unawaited(friends.refresh())),
        ),
      for (final r in friends.incoming)
        _row(
          title: r.fromName.toUpperCase(),
          text: 'Wants to be friends${_division(r.fromFaction)}.',
          below: Row(
            children: [
              Expanded(
                child: BracketButton(
                  label: 'ACCEPT',
                  height: 38,
                  palette: _p,
                  accent: widget.accent,
                  onTap: () => _do(() => friends.accept(r)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quiet('DECLINE', () => _do(() => friends.dismiss(r))),
              ),
            ],
          ),
        ),
      for (final r in friends.outgoing)
        _row(
          title: 'REQUEST SENT',
          text: r.toCode == null
              ? 'Waiting for them to accept.'
              : 'Waiting for ${FriendCode.pretty(r.toCode!)} to accept.',
          trailing: _quiet('CANCEL', () => _do(() => friends.dismiss(r))),
        ),
      _row(
        title: friends.friends.isEmpty
            ? 'FRIENDS'
            : 'FRIENDS  ·  ${friends.friends.length}',
        text: friends.friends.isEmpty
            ? (friends.loading && !friends.loaded
                  ? 'Loading…'
                  : 'No friends yet.')
            : 'Tap a planet to visit.',
        below: friends.friends.isEmpty
            ? null
            : _PlanetGrid(
                friends: friends.friends,
                isOnline: friends.isOnline,
                seenLabel: friends.seenLabel,
                palette: _p,
                onTap: (f) =>
                    Navigator.of(context).push(FriendPlanetScreen.route(f)),
              ),
      ),
    ];
  }

  String _division(String? faction) {
    final id = FactionId.values.where((f) => f.name == faction).firstOrNull;
    final name = id == null ? null : FactionService.catalog[id]?.name;
    return name == null ? '' : ' · $name';
  }

  Future<void> _do(Future<void> Function() change) async {
    try {
      await change();
    } on FriendException catch (e) {
      if (mounted) {
        showAppSnack(e.message, isError: true, fallbackContext: context);
      }
    }
  }

  Future<void> _add(FriendService friends) async {
    final said = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _AddFriendDialog(
        friends: friends,
        palette: _p,
        accent: widget.accent,
      ),
    );
    if (said != null && mounted) showAppSnack(said, fallbackContext: context);
  }

  Widget _quiet(String label, VoidCallback onTap) => ColoredBox(
    color: _p.bg0,
    child: BracketButton(
      label: label,
      onTap: onTap,
      palette: _p,
      accent: widget.accent,
      height: 36,
      primary: false,
    ),
  );

  Widget _row({
    required String title,
    String? text,
    Widget? trailing,
    Widget? below,
  }) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _mono(11.5, _p.ink)),
                  if (text != null) ...[
                    const SizedBox(height: 4),
                    Text(text, style: _prose(context, _p.muted)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing],
          ],
        ),
        if (below != null) ...[const SizedBox(height: 12), below],
      ],
    ),
  );
}

/// Friends' planets, three across, each still, with its owner's name: a
/// green dot by it while they are in the game, and when they were last
/// seen under it after.
class _PlanetGrid extends StatelessWidget {
  const _PlanetGrid({
    required this.friends,
    required this.isOnline,
    required this.seenLabel,
    required this.palette,
    required this.onTap,
  });

  final List<FriendCard> friends;
  final bool Function(String uid) isOnline;
  final String? Function(String uid) seenLabel;
  final BracketPalette palette;
  final ValueChanged<FriendCard> onTap;

  @override
  Widget build(BuildContext context) {
    // Every tile keeps the line when any has one, so they stay one height.
    final seen = {for (final f in friends) f.uid: seenLabel(f.uid)};
    final anySeen = seen.values.any((s) => s != null);
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final w = (box.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final f in friends)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: context.soundTap(() => onTap(f)),
                child: Container(
                  width: w,
                  color: palette.bg0,
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                  child: Column(
                    children: [
                      // The glow fades out before the tile's edge, and
                      // nothing it wears reaches the next one.
                      ClipRect(
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const RadialGradient(
                            colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                            stops: [0.62, 1.0],
                          ).createShader(rect),
                          child: SizedBox.square(
                            dimension: w - 8,
                            // Not built yet: the plain grey one, dim.
                            child: Opacity(
                              opacity: f.planet == null ? 0.4 : 1,
                              child: HomePlanetView(
                                look: f.planet,
                                fill: 0.62,
                                animate: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isOnline(f.uid)) ...[
                            const HomeNoticeDot(
                              color: kFriendOnlineColor,
                              size: 8,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: _mono(10.5, palette.ink, spacing: 0.8),
                            ),
                          ),
                          // Their trade table waits on this player.
                          if (context.select<TradeService?, bool>(
                            (t) => t?.attentionWith(f.uid) ?? false,
                          )) ...[
                            const SizedBox(width: 5),
                            const HomeNoticeDot(
                              color: Color(0xFFE4C16A),
                              size: 8,
                            ),
                          ],
                        ],
                      ),
                      if (anySeen) ...[
                        const SizedBox(height: 2),
                        Text(
                          seen[f.uid] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: _prose(context, palette.muted, size: 10),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Asks for a friend's code and sends the request.
class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog({
    required this.friends,
    required this.palette,
    required this.accent,
  });

  final FriendService friends;
  final BracketPalette palette;
  final Color accent;

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final said = await widget.friends.sendRequest(_code.text);
      if (mounted) Navigator.of(context).pop(said);
    } on FriendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final edge = UnderlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: p.bg0, width: 1.5),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        color: p.bg1,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ADD A FRIEND',
              style: _mono(14, p.ink).copyWith(letterSpacing: 1.8),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _code,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              cursorColor: widget.accent,
              style: _mono(18, p.ink, spacing: 3),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'ABCD-2345',
                hintStyle: _mono(
                  18,
                  p.muted.withValues(alpha: 0.5),
                  spacing: 3,
                ),
                filled: true,
                fillColor: p.bg0,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
                border: edge,
                enabledBorder: edge,
                focusedBorder: edge.copyWith(
                  borderSide: BorderSide(color: widget.accent, width: 1.5),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: _prose(context, const Color(0xFFE57373), size: 13),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ColoredBox(
                    color: p.bg0,
                    child: BracketButton(
                      label: 'CANCEL',
                      height: 42,
                      palette: p,
                      accent: widget.accent,
                      primary: false,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BracketButton(
                    label: _busy ? 'SENDING…' : 'SEND',
                    height: 42,
                    palette: p,
                    accent: widget.accent,
                    enabled: !_busy,
                    onTap: _send,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
