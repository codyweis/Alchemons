import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/web_ads.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _mono = 'monospace';
const _caseTop = Color(0xFF100C07);
const _caseBottom = Color(0xFF060504);
const _edge = Color(0xFF4A3618);
const _edgeLit = Color(0xFFC79A48);
const _gold = Color(0xFFE4C16A);
const _goldBright = Color(0xFFF6DD94);
const _goldDeep = Color(0xFFA9813F);
const _muted = Color(0xFF85827C);
const _ink = Color(0xFF1B1205);

/// The browser build's stand-in for gold packs: there is no store on the
/// web, so the shop offers gold for a rewarded ad instead, a few a day.
class WebAdGoldCard extends StatefulWidget {
  const WebAdGoldCard({super.key, required this.onResult});

  /// Reports the outcome for the shop's toast.
  final void Function(String message, {required bool ok}) onResult;

  @override
  State<WebAdGoldCard> createState() => _WebAdGoldCardState();
}

class _WebAdGoldCardState extends State<WebAdGoldCard> {
  int? _left;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final left = await WebAds.rewardsLeftToday();
    if (mounted) setState(() => _left = left);
  }

  Future<void> _watch() async {
    if (_playing) return;
    setState(() => _playing = true);
    final db = context.read<AlchemonsDatabase>();
    final watched = await WebAds.rewarded('shop_gold');
    if (watched) {
      await db.currencyDao.addGold(WebAds.rewardGold);
      await WebAds.countReward();
    }
    if (!mounted) return;
    setState(() => _playing = false);
    await _refresh();
    widget.onResult(
      watched
          ? '+${WebAds.rewardGold} gold'
          : 'No ad available right now. Try again later.',
      ok: watched,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = WebAds.enabled;
    final left = _left;
    final canWatch = enabled && !_playing && left != null && left > 0;
    final label = !enabled
        ? 'ADS UNAVAILABLE'
        : _playing
        ? 'PLAYING…'
        : left == 0
        ? 'BACK TOMORROW'
        : 'WATCH AD';
    final note = !enabled
        ? 'No ads available right now (not set up yet, or blocked by the '
              'browser). Gold packs are in the iOS and Android apps.'
        : left == null
        ? ''
        : '$left of ${WebAds.rewardsPerDay} left today.';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_caseTop, _caseBottom],
        ),
        border: Border.all(color: _edge),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'GOLD FOR AN AD',
                  style: TextStyle(
                    fontFamily: _mono,
                    color: _goldDeep,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.6,
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Text(
                      '+${WebAds.rewardGold}',
                      style: TextStyle(
                        fontFamily: _mono,
                        color: _goldBright,
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 6),
                    CoinIcon.gold(size: 18),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: context.soundAction(canWatch ? _watch : null),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: canWatch
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFF4D684),
                          Color(0xFFD9A443),
                          Color(0xFFA9711F),
                        ],
                      )
                    : null,
                color: canWatch ? null : const Color(0xFF15100A),
                border: Border.all(
                  color: canWatch
                      ? const Color(0xFFFFE9A8).withValues(alpha: 0.55)
                      : (enabled ? _edgeLit : _edge),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: _mono,
                  color: canWatch ? _ink : (enabled ? _gold : _muted),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
