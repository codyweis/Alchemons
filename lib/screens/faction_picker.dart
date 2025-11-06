// lib/screens/faction_picker_dialog.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:alchemons/models/faction.dart';
import 'dart:math' as math;

class FactionPickerDialog extends StatefulWidget {
  const FactionPickerDialog({super.key});

  @override
  State<FactionPickerDialog> createState() => _FactionPickerDialogState();
}

class _FactionPickerDialogState extends State<FactionPickerDialog>
    with TickerProviderStateMixin {
  FactionDef? _selectedFaction;
  late AnimationController _slideController;
  late AnimationController _particleController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Particle animation for background
    _particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Pulse animation for glow effects
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _selectFaction(FactionDef faction) {
    setState(() {
      _selectedFaction = faction;
    });
    _slideController.forward();
  }

  Color _getFactionColor(FactionDef faction) {
    switch (faction.name.toLowerCase()) {
      case 'mystics':
      case 'arcane':
        return const Color(0xFF8B5CF6);
      case 'technicians':
      case 'tech':
        return const Color(0xFF0EA5E9);
      case 'naturalists':
      case 'nature':
        return const Color(0xFF10B981);
      case 'warriors':
      case 'combat':
        return const Color(0xFFEF4444);
      case 'scholars':
      case 'research':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: screenSize.height * 0.85,
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 720),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.15), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(.08),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Animated particle background
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedBuilder(
                    animation: _particleController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: ParticlePainter(
                          animation: _particleController.value,
                          color: Colors.white.withOpacity(0.10),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Main content
              Column(
                children: [
                  // Header with DNA helix animation
                  _AnimatedHeader(isSmallScreen: isSmallScreen),

                  // Content area
                  Expanded(
                    child: Stack(
                      children: [
                        // Main faction list
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          transform: Matrix4.identity()
                            ..translate(
                              _selectedFaction != null
                                  ? -screenSize.width
                                  : 0.0,
                            ),
                          child: SizedBox(
                            width: double.infinity,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              physics: const BouncingScrollPhysics(),
                              itemCount: Factions.all.length,
                              itemBuilder: (context, index) {
                                final faction = Factions.all[index];
                                final isSelected =
                                    _selectedFaction?.id == faction.id;
                                return _FactionCard(
                                  faction: faction,
                                  isSelected: isSelected,
                                  isCompact: false,
                                  onTap: () => _selectFaction(faction),
                                  color: _getFactionColor(faction),
                                  pulseAnimation: _pulseController,
                                );
                              },
                            ),
                          ),
                        ),

                        // Details panel
                        if (_selectedFaction != null)
                          SlideTransition(
                            position: _slideAnimation,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(.28),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(.12),
                                  ),
                                ),
                                child: _DetailsPanel(
                                  faction: _selectedFaction!,
                                  color: _getFactionColor(_selectedFaction!),
                                  onConfirm: () => Navigator.pop(
                                    context,
                                    _selectedFaction!.id,
                                  ),
                                  onBack: () {
                                    _slideController.reverse().then((_) {
                                      setState(() => _selectedFaction = null);
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Animated DNA Helix Header (dark glass)
class _AnimatedHeader extends StatefulWidget {
  final bool isSmallScreen;

  const _AnimatedHeader({required this.isSmallScreen});

  @override
  State<_AnimatedHeader> createState() => _AnimatedHeaderState();
}

class _AnimatedHeaderState extends State<_AnimatedHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _helixController;

  @override
  void initState() {
    super.initState();
    _helixController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _helixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.isSmallScreen ? 16 : 20),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Stack(
        children: [
          // DNA Helix background
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              child: AnimatedBuilder(
                animation: _helixController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: DNAHelixPainter(animation: _helixController.value),
                  );
                },
              ),
            ),
          ),

          // Header content
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AnimatedIcon(
                    icon: Icons.science_outlined,
                    isSmallScreen: widget.isSmallScreen,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'SELECT DIVISION',
                      style: TextStyle(
                        fontSize: widget.isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFE8EAED),
                        letterSpacing: .6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Choose your specialization to begin field research',
                style: TextStyle(
                  fontSize: widget.isSmallScreen ? 11 : 12.5,
                  color: Colors.white.withOpacity(.7),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Animated rotating icon
class _AnimatedIcon extends StatefulWidget {
  final IconData icon;
  final bool isSmallScreen;

  const _AnimatedIcon({required this.icon, required this.isSmallScreen});

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: widget.isSmallScreen ? 22 : 26,
          ),
        );
      },
    );
  }
}

class _FactionCard extends StatefulWidget {
  final FactionDef faction;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;
  final Color color;
  final AnimationController pulseAnimation;

  const _FactionCard({
    required this.faction,
    required this.isSelected,
    required this.isCompact,
    required this.onTap,
    required this.color,
    required this.pulseAnimation,
  });

  @override
  State<_FactionCard> createState() => _FactionCardState();
}

class _FactionCardState extends State<_FactionCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _shimmerController;
  late Animation<double> _rotationAnimation;
  double _rotateX = 0.0;
  double _rotateY = 0.0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      onPanUpdate: (details) {
        setState(() {
          _rotateY = details.localPosition.dx / 100 - 1;
          _rotateX = details.localPosition.dy / 100 - 1;
        });
      },
      onPanEnd: (_) {
        setState(() {
          _rotateX = 0;
          _rotateY = 0;
        });
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.pulseAnimation,
          _shimmerController,
        ]),
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(_rotateX * 0.3)
              ..rotateY(_rotateY * 0.3)
              ..scale(_isPressed ? 0.97 : 1.0),
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? widget.color.withOpacity(0.12)
                    : Colors.white.withOpacity(.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isSelected
                      ? widget.color.withOpacity(.6)
                      : Colors.white.withOpacity(.14),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isSelected
                        ? widget.color.withOpacity(
                            0.25 + widget.pulseAnimation.value * 0.2,
                          )
                        : Colors.black.withOpacity(.25),
                    blurRadius: widget.isSelected
                        ? 18 + widget.pulseAnimation.value * 10
                        : 10,
                    offset: const Offset(0, 6),
                    spreadRadius: widget.isSelected
                        ? widget.pulseAnimation.value * 2
                        : 0,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Holographic shimmer effect
                  if (widget.isSelected)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: CustomPaint(
                          painter: ShimmerPainter(
                            animation: _rotationAnimation.value,
                            color: widget.color,
                          ),
                        ),
                      ),
                    ),

                  // Card content
                  widget.isCompact ? _buildCompactCard() : _buildFullCard(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactCard() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text(widget.faction.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.faction.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFE8EAED),
              ),
            ),
          ),
          if (widget.isSelected)
            Icon(Icons.check_circle, color: widget.color, size: 18),
        ],
      ),
    );
  }

  Widget _buildFullCard() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.color.withOpacity(0.35)),
                ),
                child: Text(
                  widget.faction.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.faction.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE8EAED),
                        letterSpacing: .3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'RESEARCH DIVISION',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(.8),
                size: 14,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tap to view specializations →',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  final FactionDef faction;
  final Color color;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const _DetailsPanel({
    required this.faction,
    required this.color,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.03),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(.08)),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(.12)),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    size: 16,
                    color: Colors.white.withOpacity(.85),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  faction.name,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: .4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Text(
                faction.emoji,
                style: TextStyle(fontSize: isSmallScreen ? 24 : 28),
              ),
            ],
          ),
        ),

        // Specializations
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'SPECIALIZATIONS',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFE8EAED),
                        letterSpacing: .6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...faction.perks.asMap().entries.map(
                  (entry) => _PerkCard(
                    perk: entry.value,
                    color: color,
                    index: entry.key,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Confirm button
        _AnimatedConfirmButton(
          color: color,
          factionName: faction.name,
          onConfirm: onConfirm,
          isSmallScreen: isSmallScreen,
        ),
      ],
    );
  }
}

// Animated confirm button with glow + gradient
class _AnimatedConfirmButton extends StatefulWidget {
  final Color color;
  final String factionName;
  final VoidCallback onConfirm;
  final bool isSmallScreen;

  const _AnimatedConfirmButton({
    required this.color,
    required this.factionName,
    required this.onConfirm,
    required this.isSmallScreen,
  });

  @override
  State<_AnimatedConfirmButton> createState() => _AnimatedConfirmButtonState();
}

class _AnimatedConfirmButtonState extends State<_AnimatedConfirmButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(widget.isSmallScreen ? 12 : 16),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final glow = 0.3 + math.sin(_controller.value * 2 * math.pi) * 0.2;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(glow),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withOpacity(.95),
                      widget.color.withOpacity(.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(.18)),
                ),
                child: ElevatedButton(
                  onPressed: widget.onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'JOIN ${widget.factionName.toUpperCase()}',
                        style: TextStyle(
                          fontSize: widget.isSmallScreen ? 13.5 : 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: .6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PerkCard extends StatefulWidget {
  final dynamic perk;
  final Color color;
  final int index;

  const _PerkCard({
    required this.perk,
    required this.color,
    required this.index,
  });

  @override
  State<_PerkCard> createState() => _PerkCardState();
}

class _PerkCardState extends State<_PerkCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // Stagger animation based on index
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.perk.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: widget.color,
                      letterSpacing: .4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                widget.perk.description,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFFE8EAED).withOpacity(.85),
                  height: 1.28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== Custom Painters ===================

// Particle system background painter
class ParticlePainter extends CustomPainter {
  final double animation;
  final Color color;

  ParticlePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Create floating particles
    for (int i = 0; i < 30; i++) {
      final x = (size.width / 30 * i + animation * 50) % size.width;
      final y =
          (size.height / 30 * i + math.sin(animation * 2 * math.pi + i) * 50) %
          size.height;
      final radius = 2 + math.sin(animation * 2 * math.pi + i) * 1;

      canvas.drawCircle(Offset(x, y), radius, paint);

      // Draw connections between nearby particles
      for (int j = i + 1; j < 30; j++) {
        final x2 = (size.width / 30 * j + animation * 50) % size.width;
        final y2 =
            (size.height / 30 * j +
                math.sin(animation * 2 * math.pi + j) * 50) %
            size.height;

        final distance = math.sqrt(math.pow(x2 - x, 2) + math.pow(y2 - y, 2));

        if (distance < 100) {
          final linePaint = Paint()
            ..color = color.withOpacity((1 - distance / 100) * 0.35)
            ..strokeWidth = 0.5;
          canvas.drawLine(Offset(x, y), Offset(x2, y2), linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

// DNA Helix painter (lighter on dark)
class DNAHelixPainter extends CustomPainter {
  final double animation;

  DNAHelixPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    // Draw helix strands
    final path1 = Path();
    final path2 = Path();

    for (double i = 0; i < size.width; i += 2) {
      final progress = i / size.width;
      final y1 =
          size.height / 2 + math.sin((progress + animation) * 4 * math.pi) * 15;
      final y2 =
          size.height / 2 +
          math.sin((progress + animation + 0.5) * 4 * math.pi) * 15;

      if (i == 0) {
        path1.moveTo(i, y1);
        path2.moveTo(i, y2);
      } else {
        path1.lineTo(i, y1);
        path2.lineTo(i, y2);
      }

      // Dots + connectors
      if (i % 20 == 0) {
        canvas.drawCircle(Offset(i, y1), 2, dotPaint);
        canvas.drawCircle(Offset(i, y2), 2, dotPaint);

        final connectorPaint = Paint()
          ..color = Colors.white.withOpacity(0.12)
          ..strokeWidth = 1;
        canvas.drawLine(Offset(i, y1), Offset(i, y2), connectorPaint);
      }
    }

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(DNAHelixPainter oldDelegate) => true;
}

// Holographic shimmer effect painter
class ShimmerPainter extends CustomPainter {
  final double animation;
  final Color color;

  ShimmerPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.transparent, color.withOpacity(0.12), Colors.transparent],
      stops: [animation - 0.3, animation, animation + 0.3],
    );

    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(ShimmerPainter oldDelegate) => true;
}
