import 'package:flutter/material.dart';
import 'package:alchemons/utils/faction_util.dart'; // FactionTheme

class BottomSheetShell extends StatelessWidget {
  final FactionTheme theme;
  final String title;
  final Widget child;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  const BottomSheetShell({
    super.key,
    required this.theme,
    required this.title,
    required this.child,
    this.initialChildSize = 0.7,
    this.minChildSize = 0.4,
    this.maxChildSize = .95,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      expand: false,
      builder: (context, scrollController) {
        // We’re going to give scrollController to the inner content via
        // _SheetBodyWrapper so it can drive its own grid/list scroll.
        return Padding(
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.text, width: 1),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.text.withOpacity(.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // header row (title + close)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),

                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: theme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // body region:
                // We want the child to control scrolling using the draggable
                // sheet's scrollController.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: SheetBodyWrapper(
                      scrollController: scrollController,
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Gives the sheet's ScrollController to descendants so they can
/// make just their list/grid scroll, while keeping their own headers pinned.
class SheetBodyWrapper extends InheritedWidget {
  final ScrollController scrollController;
  const SheetBodyWrapper({
    required this.scrollController,
    required Widget child,
    super.key,
  }) : super(child: child);

  static ScrollController? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SheetBodyWrapper>();
    return scope?.scrollController;
  }

  @override
  bool updateShouldNotify(SheetBodyWrapper oldWidget) =>
      oldWidget.scrollController != scrollController;
}
