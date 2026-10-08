import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/nursery/cultivation_stage.dart';
import 'package:alchemons/widgets/fx/cultivation_sphere.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

class ExtractionDialog extends StatefulWidget {
  final IncubatorSlot slot;
  final Color primaryColor;
  final bool isUndiscovered;
  final VoidCallback onExtract;
  final VoidCallback onDiscard;
  final VoidCallback onCancel;
  final bool isTutorial;

  /// The chamber's sphere, flown up onto the stage.
  final CultivationFlight? arrival;

  const ExtractionDialog({
    super.key,
    required this.slot,
    required this.primaryColor,
    required this.isUndiscovered,
    required this.onExtract,
    required this.onDiscard,
    required this.onCancel,
    this.isTutorial = false,
    this.arrival,
  });

  @override
  State<ExtractionDialog> createState() => ExtractionDialogState();
}

class ExtractionDialogState extends State<ExtractionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;
  CinematicQuality _cinematicQuality = CinematicQuality.cinematic;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      duration: const Duration(milliseconds: 160),
      vsync: this,
    );
    _slideAnim = Tween<double>(
      begin: 28,
      end: 0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();
    _loadCinematicQuality();
    CinematicQualityService.qualityNotifier.addListener(
      _handleCinematicQualityChanged,
    );
  }

  void _handleCinematicQualityChanged() {
    if (!mounted) return;
    final next = CinematicQualityService.qualityNotifier.value;
    if (next != _cinematicQuality) {
      setState(() => _cinematicQuality = next);
    }
  }

  Future<void> _loadCinematicQuality() async {
    final q = await CinematicQualityService().getQuality();
    if (!mounted) return;
    setState(() => _cinematicQuality = q);
  }

  @override
  void dispose() {
    CinematicQualityService.qualityNotifier.removeListener(
      _handleCinematicQualityChanged,
    );
    _enterCtrl.dispose();
    super.dispose();
  }

  /// The sphere on the stage, handed on to the hatching ceremony so it opens
  /// on this cultivation instead of on black.
  final GlobalKey _sphereKey = GlobalKey();

  void _extract() {
    HapticFeedback.heavyImpact();
    CultivationHandoff.stage(CultivationSphere.handoffFrom(_sphereKey));
    widget.onExtract();
  }

  /// The cultivation's saved data, for its sphere.
  Map<String, dynamic> _payload() {
    try {
      final raw = widget.slot.payloadJson;
      if (raw == null || raw.isEmpty) return const {};
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  List<String>? _extractParentTypes() {
    try {
      final raw = widget.slot.payloadJson;
      if (raw == null || raw.isEmpty) return null;
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final types = extractParticleTypeIdsFromPayload(payload);
      return types.isEmpty ? null : types;
    } catch (_) {
      return null;
    }
  }

  /// The ready banner pushes harder than the in-cultivation one on purpose —
  /// completion should read as energetic.
  int _readyParticleCount(BuildContext context) {
    final media = MediaQuery.of(context);
    final shortestSide = media.size.shortestSide;
    var count = shortestSide < 380 ? 36 : (shortestSide < 430 ? 54 : 72);
    if (Scrollable.recommendDeferredLoadingForContext(context)) count = 18;
    final quality = switch (_cinematicQuality) {
      CinematicQuality.cinematic => 1.0,
      CinematicQuality.performance => 0.4,
    };
    return (count * quality).round().clamp(0, 110);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final parentTypes = _extractParentTypes();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: AnimatedBuilder(
        animation: _enterCtrl,
        builder: (context, child) => FadeTransition(
          opacity: _fadeAnim,
          child: Transform.translate(
            offset: Offset(0, _slideAnim.value),
            child: child,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // No frame. The in-cultivation dialog has none, and the corner
              // brackets were the last thing making these two read as
              // different screens.
              // Dark whatever the app theme is: the vial is a lit object,
              // and it only reads as one against a dark ground.
              // Same widget as the in-cultivation dialog. What differs is the
              // action, the left-hand icon, and that there is no countdown —
              // because there is nothing left to wait for.
              // No fill. The in-cultivation dialog paints nothing behind its
              // vial, so this was the black rectangle that still set the two
              // apart.
              CultivationVialStage(
                theme: theme,
                parentTypes: parentTypes,
                payload: _payload(),
                progress: 1,
                sphereKey: _sphereKey,
                arrival: widget.arrival,
                // A pure line's sigil is its element's, as in the reveal.
                pureElementTypeId: pureElementFromPayload(_payload()),
                chamberLabel: 'CHAMBER ${widget.slot.id + 1}',
                particleCount: _readyParticleCount(context),
                speedMultiplier: 0.22,
                // The finished look, as on the chamber card.
                fusion: true,
                onStageTap: _extract,
                action: VialActionButton(label: 'EXTRACT', onTap: _extract),
                leading: widget.isTutorial
                    ? const SizedBox(width: 40)
                    : StageIconButton(
                        icon: AppIcons.delete_outline_rounded,
                        tooltip: 'Discard specimen',
                        color: t.danger,
                        heavy: true,
                        onTap: widget.onDiscard,
                      ),
                trailing: StageIconButton(
                  icon: AppIcons.close_rounded,
                  tooltip: 'Close',
                  color: t.textSecondary,
                  onTap: widget.onCancel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER ICON BUTTON + TEXT LINK
// ─────────────────────────────────────────────────────────────────────────────
