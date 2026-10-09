// lib/widgets/specimen_search_bar.dart
//
// The search field over a grid of specimens — the Creatures tab's and the
// picker's that slides up over fusion, harvest and the rest — with RESET
// beside it once there is a sort, filter or search to clear.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

class SpecimenSearchBar extends StatefulWidget {
  const SpecimenSearchBar({
    super.key,
    required this.palette,
    required this.accent,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.showReset,
    required this.onReset,
    this.focusNode,
    this.compact,
    this.onToggleCompact,
  });

  final BracketPalette palette;
  final Color accent;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool showReset;
  final VoidCallback onReset;

  /// When [onToggleCompact] is set, a button at the right end switches the
  /// grid between 3 and 4 per row; [compact] is the 4-per-row state.
  final bool? compact;
  final VoidCallback? onToggleCompact;

  @override
  State<SpecimenSearchBar> createState() => _SpecimenSearchBarState();
}

class _SpecimenSearchBarState extends State<SpecimenSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(SpecimenSearchBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final hasText = widget.controller.text.isNotEmpty;
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: palette.ink,
    );
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            color: palette.chromeMutedFill(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(AppIcons.search_rounded, size: 15, color: palette.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    onChanged: widget.onChanged,
                    cursorColor: widget.accent,
                    style: style,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: widget.hint,
                      hintStyle: style.copyWith(color: palette.muted),
                    ),
                  ),
                ),
                if (hasText)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: context.soundAction(() {
                      widget.controller.clear();
                      widget.onChanged('');
                    }),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        AppIcons.close_rounded,
                        size: 14,
                        color: palette.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.showReset) ...[
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: context.soundAction(widget.onReset),
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: widget.accent,
                strokeWidth: 1.2,
              ),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                color: palette.accentWash(widget.accent),
                child: Text(
                  'RESET',
                  style: style.copyWith(fontSize: 11, letterSpacing: 1.2),
                ),
              ),
            ),
          ),
        ],
        if (widget.onToggleCompact != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: context.soundAction(widget.onToggleCompact),
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: widget.compact == true ? widget.accent : palette.line,
                strokeWidth: 1.2,
              ),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                color: widget.compact == true
                    ? palette.accentWash(widget.accent)
                    : null,
                child: Icon(
                  widget.compact == true
                      ? AppIcons.grid_view_rounded
                      : AppIcons.grid_nine,
                  size: 18,
                  color: widget.compact == true ? widget.accent : palette.muted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
