// lib/screens/faction_picker_dialog.dart
import 'package:flutter/material.dart';
import 'package:alchemons/models/faction.dart';

class FactionPickerDialog extends StatefulWidget {
  const FactionPickerDialog({super.key});

  @override
  State<FactionPickerDialog> createState() => _FactionPickerDialogState();
}

class _FactionPickerDialogState extends State<FactionPickerDialog>
    with TickerProviderStateMixin {
  FactionDef? _selectedFaction;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
  }

  @override
  void dispose() {
    _slideController.dispose();
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
        return const Color(0xFF8B5CF6); // Purple
      case 'technicians':
      case 'tech':
        return const Color(0xFF0EA5E9); // Sky blue
      case 'naturalists':
      case 'nature':
        return const Color(0xFF10B981); // Emerald
      case 'warriors':
      case 'combat':
        return const Color(0xFFEF4444); // Red
      case 'scholars':
      case 'research':
        return const Color(0xFF6366F1); // Indigo
      default:
        return const Color(0xFF6B7280); // Gray
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
      child: Container(
        width: double.infinity,
        height: screenSize.height * 0.85, // Use 85% of screen height
        constraints: BoxConstraints(maxWidth: 400, maxHeight: 700),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF0FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo[300]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo[600]!, Colors.indigo[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.science_outlined,
                        color: Colors.white,
                        size: isSmallScreen ? 24 : 28,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Choose Research Division',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select your specialization to begin field research',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      color: Colors.indigo[100],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content area - Stack instead of Row for mobile
            Expanded(
              child: Stack(
                children: [
                  // Main faction list
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    transform: Matrix4.identity()
                      ..translate(
                        _selectedFaction != null ? -screenSize.width : 0.0,
                      ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: Factions.all.length,
                        itemBuilder: (context, index) {
                          final faction = Factions.all[index];
                          final isSelected = _selectedFaction?.id == faction.id;
                          return _FactionCard(
                            faction: faction,
                            isSelected: isSelected,
                            isCompact: false,
                            onTap: () => _selectFaction(faction),
                            color: _getFactionColor(faction),
                          );
                        },
                      ),
                    ),
                  ),

                  // Details panel - slides over the entire dialog
                  if (_selectedFaction != null)
                    SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: const BoxDecoration(color: Colors.white),
                        child: _DetailsPanel(
                          faction: _selectedFaction!,
                          color: _getFactionColor(_selectedFaction!),
                          onConfirm: () =>
                              Navigator.pop(context, _selectedFaction!.id),
                          onBack: () {
                            _slideController.reverse().then((_) {
                              setState(() => _selectedFaction = null);
                            });
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactionCard extends StatefulWidget {
  final FactionDef faction;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;
  final Color color;

  const _FactionCard({
    required this.faction,
    required this.isSelected,
    required this.isCompact,
    required this.onTap,
    required this.color,
  });

  @override
  State<_FactionCard> createState() => _FactionCardState();
}

class _FactionCardState extends State<_FactionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? widget.color.withOpacity(0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected ? widget.color : Colors.grey[300]!,
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isSelected
                  ? widget.color.withOpacity(0.2)
                  : Colors.grey[200]!,
              blurRadius: widget.isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: widget.isCompact ? _buildCompactCard() : _buildFullCard(),
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
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: widget.isSelected ? widget.color : Colors.grey[800],
              ),
            ),
          ),
          if (widget.isSelected)
            Icon(Icons.check_circle, color: widget.color, size: 20),
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
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.color.withOpacity(0.3)),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Research Division',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: widget.color, size: 14),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tap to view specializations →',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
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
            color: color.withOpacity(0.1),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      faction.name,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: color,
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
            ],
          ),
        ),

        // Specializations
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Specializations',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...faction.perks.map(
                  (perk) => _PerkCard(perk: perk, color: color),
                ),
              ],
            ),
          ),
        ),

        // Confirm button
        Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Join ${faction.name}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PerkCard extends StatelessWidget {
  final dynamic perk; // Replace with your actual perk type
  final Color color;

  const _PerkCard({required this.perk, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  perk.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              perk.description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
