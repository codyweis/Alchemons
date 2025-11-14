// Separate stateful widget to handle dragging
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:flutter/material.dart';

class DraggableSheet extends StatefulWidget {
  final Animation<double> animation;
  final FactionTheme theme;
  final void Function(CreatureInstance) onInstanceTap;

  const DraggableSheet({
    required this.animation,
    required this.theme,
    required this.onInstanceTap,
  });

  @override
  State<DraggableSheet> createState() => _DraggableSheetState();
}

class _DraggableSheetState extends State<DraggableSheet> {
  double _dragOffset = 0.0;
  bool _isDragging = false;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      // Only allow dragging down (positive delta)
      _dragOffset = (_dragOffset + details.delta.dy).clamp(
        0.0,
        double.infinity,
      );
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    // If dragged down more than 150px or fast velocity, dismiss
    if (_dragOffset > 150 || details.velocity.pixelsPerSecond.dy > 500) {
      Navigator.of(context).pop();
    } else {
      // Snap back
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: widget.animation,
                curve: Curves.easeOutCubic,
              ),
            ),
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                height: screenHeight * 0.95,
                decoration: BoxDecoration(
                  color: widget.theme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.6),
                      blurRadius: 24,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle + Header
                    GestureDetector(
                      onVerticalDragUpdate: _onVerticalDragUpdate,
                      onVerticalDragEnd: _onVerticalDragEnd,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        decoration: BoxDecoration(
                          color: widget.theme.surface,
                          border: Border(
                            bottom: BorderSide(
                              color: widget.theme.border,
                              width: 1.5,
                            ),
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Drag handle indicator
                            Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: widget.theme.textMuted.withOpacity(.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // Header row
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ALL SPECIMENS',
                                    style: TextStyle(
                                      color: widget.theme.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .8,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: widget.theme.surfaceAlt,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: widget.theme.border,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: widget.theme.text,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Content - prevent drag from content area
                    Expanded(
                      child: GestureDetector(
                        // Absorb drag gestures in content area so grid can scroll
                        onVerticalDragStart: (_) {},
                        child: AllCreatureInstances(
                          theme: widget.theme,
                          selectedInstanceIds: const [],
                          onTap: widget.onInstanceTap,
                        ),
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
