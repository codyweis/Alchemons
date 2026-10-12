// lib/widgets/choice_strip.dart
//
// A row of choices that runs off the side and scrolls, for pickers whose
// tiles would otherwise wrap into a tall block (the profile's dock sets and
// fusion styles). The chosen one is brought into view when the strip first
// shows; choosing another never moves it.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ChoiceStrip extends StatefulWidget {
  const ChoiceStrip({
    super.key,
    required this.children,
    this.selected,
    this.padding = EdgeInsets.zero,
    this.spacing = 8,
  });

  final List<Widget> children;

  /// The index of the chosen one, shown on the first frame.
  final int? selected;
  final EdgeInsets padding;
  final double spacing;

  @override
  State<ChoiceStrip> createState() => _ChoiceStripState();
}

class _ChoiceStripState extends State<ChoiceStrip> {
  final ScrollController _scroll = ScrollController();

  /// One per child, so a child keeps its state when the choice moves.
  final List<GlobalKey> _keys = [];

  GlobalKey _keyAt(int i) {
    while (_keys.length <= i) {
      _keys.add(GlobalKey());
    }
    return _keys[i];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSelected());
  }

  /// The chosen one to the middle of the strip, as far as the strip goes.
  /// Only this strip moves: [Scrollable.ensureVisible] would also scroll
  /// the page it sits in.
  void _showSelected() {
    final i = widget.selected;
    if (!mounted || i == null || i >= _keys.length || !_scroll.hasClients) {
      return;
    }
    final box = _keys[i].currentContext?.findRenderObject();
    if (box == null) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final position = _scroll.position;
    _scroll.jumpTo(
      viewport
          .getOffsetToReveal(box, 0.5)
          .offset
          .clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: widget.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widget.children.length; i++) ...[
            if (i > 0) SizedBox(width: widget.spacing),
            KeyedSubtree(key: _keyAt(i), child: widget.children[i]),
          ],
        ],
      ),
    );
  }
}
