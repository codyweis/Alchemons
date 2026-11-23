// lib/screens/friends/friends_panel.dart
//
// FRIENDS on the profile. First what waits on the player (requests to
// answer), then their friends' home planets, those in the game first: on
// the profile one row that scrolls sideways, with ALL to every friend on a
// page of their own (friends_screen.dart), three across. A tap on a planet
// opens that friend's page (friend_planet_screen.dart). Then the requests
// the player sent, and last their own code — tapped, it is copied — with
// ADD FRIEND beside it.
//
// Signed out, it only says what signing in would bring. Laid out as the
// profile's own rows are, inside its panel.

import 'dart:async';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/screens/friends/friend_planet_screen.dart';
import 'package:alchemons/screens/friends/friends_screen.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/trade_service.dart';
import 'package:alchemons/utils/app_scaffold_messenger.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
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

final ForgeTokens _tokens = ForgeTokens(factionThemeFor(null));

/// How many planets the profile's row shows whole; past that, ALL.
const int _rowShows = 3;

class FriendsPanel extends StatefulWidget {
  const FriendsPanel({
    super.key,
    required this.palette,
    required this.accent,
    required this.onSignIn,
    this.all = false,
  });

  final BracketPalette palette;
  final Color accent;

  /// Opens the account's sign-in (SETTINGS has the rest).
  final VoidCallback onSignIn;

  /// Every friend's planet, three across (the FRIENDS page); otherwise one
  /// row of them that scrolls sideways (the profile).
  final bool all;

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

  List<Widget> _signedIn(FriendService friends) => [
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
    _planets(friends),
    for (final r in friends.outgoing)
      _row(
        title: 'REQUEST SENT',
        text: r.toCode == null
            ? 'Waiting for them to accept.'
            : 'Waiting for ${FriendCode.pretty(r.toCode!)} to accept.',
        trailing: _quiet('CANCEL', () => _do(() => friends.dismiss(r))),
      ),
    _code(friends),
  ];

  /// FRIENDS · n and their planets, those in the game first, then the most
  /// lately seen.
  Widget _planets(FriendService friends) {
    final list = [...friends.friends];
    if (list.isEmpty) {
      return _row(
        title: 'FRIENDS',
        text: friends.loading && !friends.loaded
            ? 'Loading…'
            : 'No friends yet. Give a friend your code, or add theirs.',
      );
    }
    final seenAt = {for (final f in list) f.uid: friends.seenAt(f.uid)};
    int byPresence(FriendCard a, FriendCard b) {
      final online = (friends.isOnline(b.uid) ? 1 : 0).compareTo(
        friends.isOnline(a.uid) ? 1 : 0,
      );
      if (online != 0) return online;
      final x = seenAt[a.uid], y = seenAt[b.uid];
      if (x != y) {
        if (x == null) return 1;
        if (y == null) return -1;
        final later = y.compareTo(x);
        if (later != 0) return later;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }

    list.sort(byPresence);
    final title = 'FRIENDS · ${list.length}';
    void open(FriendCard f) =>
        Navigator.of(context).push(FriendPlanetScreen.route(f));
    // "5 minutes ago" under the name, which says who was seen; their page
    // says it whole ("Seen 5 minutes ago").
    final now = DateTime.now();
    String? lastSeen(String uid) {
      final at = friends.seenAt(uid);
      return friends.isOnline(uid) || at == null ? null : agoLabel(at, now);
    }

    if (widget.all) {
      return _row(
        title: title,
        below: _PlanetGrid(
          friends: list,
          isOnline: friends.isOnline,
          seenLabel: lastSeen,
          palette: _p,
          onTap: open,
        ),
      );
    }
    // The row runs to the panel's edges, so a planet past the last whole
    // one shows at the edge and the row reads as one that scrolls.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(child: Text(title, style: _mono(11.5, _p.ink))),
                if (list.length > _rowShows)
                  _quiet(
                    'ALL',
                    () => Navigator.of(context).push(FriendsScreen.route()),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PlanetRow(
            friends: list,
            isOnline: friends.isOnline,
            seenLabel: lastSeen,
            palette: _p,
            onTap: open,
          ),
        ],
      ),
    );
  }

  /// YOUR CODE, copied when tapped, and ADD FRIEND for theirs.
  Widget _code(FriendService friends) {
    final code = friends.code;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR CODE', style: _mono(11.5, _p.ink)),
                const SizedBox(height: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: code == null
                      ? null
                      : context.soundTap(() {
                          unawaited(
                            Clipboard.setData(ClipboardData(text: code)),
                          );
                          HapticFeedback.selectionClick();
                          showAppSnack(
                            'Code copied.',
                            fallbackContext: context,
                          );
                        }),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            code ?? (friends.loading ? '…' : '—'),
                            style: _mono(20, _p.ink, spacing: 3),
                          ),
                        ),
                      ),
                      if (code != null) ...[
                        const SizedBox(width: 8),
                        Icon(AppIcons.copy_rounded, size: 15, color: _p.muted),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          BracketButton(
            label: 'ADD FRIEND',
            height: 38,
            palette: _p,
            accent: widget.accent,
            enabled: code != null,
            onTap: () => _add(friends),
          ),
        ],
      ),
    );
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

/// The profile's row of friends' planets, scrolling sideways. Each is
/// drawn once and kept (a repaint boundary), so moving the row only moves
/// pictures.
class _PlanetRow extends StatelessWidget {
  const _PlanetRow({
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

  /// A little narrower than a third of the row, so a fourth planet shows
  /// at the edge.
  static const double _width = 96;

  @override
  Widget build(BuildContext context) {
    final seen = {for (final f in friends) f.uid: seenLabel(f.uid)};
    final anySeen = seen.values.any((s) => s != null);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, f) in friends.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            RepaintBoundary(
              child: _PlanetTile(
                friend: f,
                width: _width,
                online: isOnline(f.uid),
                seen: anySeen ? (seen[f.uid] ?? '') : null,
                palette: palette,
                onTap: () => onTap(f),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every friend's planet, three across: the FRIENDS page.
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
    // Every tile keeps a line when any has one, so they stay one height.
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
              _PlanetTile(
                friend: f,
                width: w,
                online: isOnline(f.uid),
                seen: anySeen ? (seen[f.uid] ?? '') : null,
                palette: palette,
                onTap: () => onTap(f),
              ),
          ],
        );
      },
    );
  }
}

/// A friend's planet, still, with their name under it: a green dot by it
/// while they are in the game, a gold one while their trade table waits on
/// the player, and when they were last seen under that.
class _PlanetTile extends StatelessWidget {
  const _PlanetTile({
    required this.friend,
    required this.width,
    required this.online,
    required this.seen,
    required this.palette,
    required this.onTap,
  });

  final FriendCard friend;
  final double width;
  final bool online;

  /// How long ago they were last seen; '' keeps the line empty (so tiles
  /// stay one height), null leaves it out.
  final String? seen;
  final BracketPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = friend;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundTap(onTap),
      child: Container(
        width: width,
        color: palette.bg0,
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Column(
          children: [
            // The glow fades out before the tile's edge, and nothing it
            // wears reaches the next one.
            ClipRect(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const RadialGradient(
                  colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                  stops: [0.62, 1.0],
                ).createShader(rect),
                child: SizedBox.square(
                  dimension: width - 8,
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
                if (online) ...[
                  const HomeNoticeDot(color: kFriendOnlineColor, size: 8),
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
                  HomeNoticeDot(color: _tokens.rewardGold, size: 8),
                ],
              ],
            ),
            if (seen case final line?) ...[
              const SizedBox(height: 2),
              Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _prose(context, palette.muted, size: 10),
              ),
            ],
          ],
        ),
      ),
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
                style: _prose(context, kLeaveDangerAccent, size: 13),
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
