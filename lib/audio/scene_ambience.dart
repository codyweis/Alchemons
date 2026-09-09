import 'package:flutter/widgets.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'audio.dart';
import 'ambience_player.dart';
export 'ambience_player.dart' show AmbienceCue;

final ambienceRouteObserver = RouteObserver<ModalRoute<dynamic>>();

/// Rebuilds do not restart a loop. Covered routes relinquish their ambience,
/// then reclaim it when the player returns, including non-ambience destinations.
class SceneAmbience extends StatefulWidget {
  const SceneAmbience({super.key, required this.cue, required this.child});
  final AmbienceCue? cue;
  final Widget child;
  @override
  State<SceneAmbience> createState() => _SceneAmbienceState();
}

class _SceneAmbienceState extends State<SceneAmbience> with RouteAware {
  AudioController? _audio;
  ModalRoute<dynamic>? _route;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.audio;
    if (!identical(next, _audio)) _audio?.stopAmbienceOwner(this);
    _audio = next;
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      ambienceRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) ambienceRouteObserver.subscribe(this, route);
    }
    _visible = route?.isCurrent ?? true;
    _sync();
  }

  @override
  void didUpdateWidget(SceneAmbience oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final cue = widget.cue;
    if (_visible && cue != null) {
      _audio?.setAmbience(this, cue);
    } else {
      _audio?.stopAmbienceOwner(this);
    }
  }

  @override
  void didPushNext() {
    _visible = false;
    _sync();
  }

  @override
  void didPopNext() {
    _visible = true;
    _sync();
  }

  @override
  void didPop() {
    _visible = false;
    _sync();
  }

  @override
  void dispose() {
    ambienceRouteObserver.unsubscribe(this);
    _audio?.stopAmbienceOwner(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
