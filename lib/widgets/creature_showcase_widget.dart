// import 'package:alchemons/providers/app_providers.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// List<String> _featuredCreatureIds = [];
// void _initializeFeaturedCreatures(
//   List<Map<String, dynamic>> discoveredCreatures,
// ) {
//   if (_featuredCreatureIds.isEmpty && discoveredCreatures.isNotEmpty) {
//     _featuredCreatureIds = discoveredCreatures
//         .take(3)
//         .map((data) => (data['creature'] as Creature).id)
//         .toList();
//   }
// }

// void _showCreatureSelector(List<Map<String, dynamic>> availableCreatures) {
//   List<String> tempFeaturedIds = List.from(_featuredCreatureIds);

//   showModalBottomSheet(
//     context: context,
//     backgroundColor: Colors.transparent,
//     isScrollControlled: true,
//     builder: (context) => StatefulBuilder(
//       builder: (BuildContext context, StateSetter setModalState) {
//         return Container(
//           height: MediaQuery.of(context).size.height * 0.75,
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [Colors.white, Colors.indigo.shade50],
//             ),
//             borderRadius: const BorderRadius.only(
//               topLeft: Radius.circular(24),
//               topRight: Radius.circular(24),
//             ),
//             border: Border.all(color: Colors.indigo.shade300, width: 2),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.indigo.shade200,
//                 blurRadius: 20,
//                 offset: const Offset(0, -4),
//               ),
//             ],
//           ),
//           child: Column(
//             children: [
//               Container(
//                 margin: const EdgeInsets.only(top: 12, bottom: 8),
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: Colors.indigo.shade300,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               Container(
//                 margin: const EdgeInsets.symmetric(
//                   horizontal: 20,
//                   vertical: 12,
//                 ),
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(color: Colors.indigo.shade200, width: 2),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.indigo.shade100,
//                       blurRadius: 8,
//                       offset: const Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             color: Colors.indigo.shade50,
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: Icon(
//                             Icons.science_rounded,
//                             color: Colors.indigo.shade600,
//                             size: 20,
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Text(
//                             'Configure Display Specimens',
//                             style: TextStyle(
//                               color: Colors.indigo.shade800,
//                               fontSize: 16,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 6,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.indigo.shade50,
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: Colors.indigo.shade200),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(
//                             Icons.check_circle,
//                             color: Colors.indigo.shade600,
//                             size: 14,
//                           ),
//                           const SizedBox(width: 6),
//                           Text(
//                             'Selected: ${tempFeaturedIds.length}/3',
//                             style: TextStyle(
//                               color: Colors.indigo.shade700,
//                               fontSize: 13,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Expanded(
//                 child: GridView.builder(
//                   padding: const EdgeInsets.symmetric(horizontal: 20),
//                   physics: const BouncingScrollPhysics(),
//                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                     crossAxisCount: 3,
//                     childAspectRatio: 0.85,
//                     crossAxisSpacing: 12,
//                     mainAxisSpacing: 12,
//                   ),
//                   itemCount: availableCreatures.length,
//                   itemBuilder: (context, index) {
//                     final creatureData = availableCreatures[index];
//                     final creature = creatureData['creature'] as Creature;
//                     final isSelected = tempFeaturedIds.contains(creature.id);
//                     final typeColor = BreedConstants.getTypeColor(
//                       creature.types.first,
//                     );

//                     return GestureDetector(
//                       onTap: () {
//                         HapticFeedback.selectionClick();
//                         setModalState(() {
//                           if (isSelected) {
//                             tempFeaturedIds.remove(creature.id);
//                           } else {
//                             if (tempFeaturedIds.length < 3) {
//                               tempFeaturedIds.add(creature.id);
//                             } else {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                   content: const Text(
//                                     'Maximum 3 specimens allowed',
//                                   ),
//                                   backgroundColor: Colors.orange.shade600,
//                                   duration: const Duration(seconds: 2),
//                                   behavior: SnackBarBehavior.floating,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                               );
//                             }
//                           }
//                         });
//                       },
//                       child: AnimatedContainer(
//                         duration: const Duration(milliseconds: 300),
//                         curve: Curves.easeOutCubic,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                             color: isSelected
//                                 ? Colors.indigo.shade600
//                                 : typeColor.withOpacity(0.3),
//                             width: isSelected ? 3 : 2,
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: isSelected
//                                   ? Colors.indigo.shade300
//                                   : typeColor.withOpacity(0.2),
//                               blurRadius: isSelected ? 12 : 6,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: Stack(
//                           children: [
//                             if (isSelected)
//                               Positioned.fill(
//                                 child: Container(
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(14),
//                                     gradient: RadialGradient(
//                                       colors: [
//                                         Colors.indigo.withOpacity(0.1),
//                                         Colors.transparent,
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             Padding(
//                               padding: const EdgeInsets.all(8),
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Expanded(
//                                     child: Container(
//                                       decoration: BoxDecoration(
//                                         color: typeColor.withOpacity(0.1),
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                       child: ClipRRect(
//                                         borderRadius: BorderRadius.circular(12),
//                                         child: Image.asset(
//                                           'assets/images/${creature.image}',
//                                           fit: BoxFit.contain,
//                                           errorBuilder:
//                                               (context, error, stackTrace) {
//                                                 return Icon(
//                                                   BreedConstants.getTypeIcon(
//                                                     creature.types.first,
//                                                   ),
//                                                   color: typeColor,
//                                                   size: 32,
//                                                 );
//                                               },
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     creature.name,
//                                     style: TextStyle(
//                                       color: Colors.indigo.shade800,
//                                       fontSize: 11,
//                                       fontWeight: FontWeight.w700,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             if (isSelected) ...[
//                               Positioned(
//                                 top: 6,
//                                 right: 6,
//                                 child: Container(
//                                   width: 24,
//                                   height: 24,
//                                   decoration: BoxDecoration(
//                                     color: Colors.indigo.shade600,
//                                     shape: BoxShape.circle,
//                                     boxShadow: [
//                                       BoxShadow(
//                                         color: Colors.indigo.shade300,
//                                         blurRadius: 4,
//                                       ),
//                                     ],
//                                   ),
//                                   child: const Icon(
//                                     Icons.check,
//                                     color: Colors.white,
//                                     size: 16,
//                                   ),
//                                 ),
//                               ),
//                               Positioned(
//                                 top: 6,
//                                 left: 6,
//                                 child: Container(
//                                   width: 20,
//                                   height: 20,
//                                   decoration: BoxDecoration(
//                                     color: Colors.white,
//                                     shape: BoxShape.circle,
//                                     border: Border.all(
//                                       color: Colors.indigo.shade600,
//                                       width: 2,
//                                     ),
//                                   ),
//                                   child: Center(
//                                     child: Text(
//                                       '${tempFeaturedIds.indexOf(creature.id) + 1}',
//                                       style: TextStyle(
//                                         color: Colors.indigo.shade700,
//                                         fontSize: 10,
//                                         fontWeight: FontWeight.w800,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: const BorderRadius.only(
//                     topLeft: Radius.circular(20),
//                     topRight: Radius.circular(20),
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.indigo.shade100,
//                       blurRadius: 12,
//                       offset: const Offset(0, -2),
//                     ),
//                   ],
//                 ),
//                 child: Row(
//                   children: [
//                     if (tempFeaturedIds.isNotEmpty)
//                       Expanded(
//                         child: GestureDetector(
//                           onTap: () {
//                             HapticFeedback.lightImpact();
//                             setModalState(() {
//                               tempFeaturedIds.clear();
//                             });
//                           },
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             margin: const EdgeInsets.only(right: 8),
//                             decoration: BoxDecoration(
//                               color: Colors.grey.shade100,
//                               borderRadius: BorderRadius.circular(12),
//                               border: Border.all(color: Colors.grey.shade300),
//                             ),
//                             child: Text(
//                               'Clear All',
//                               style: TextStyle(
//                                 color: Colors.grey.shade700,
//                                 fontWeight: FontWeight.w700,
//                                 fontSize: 14,
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                           ),
//                         ),
//                       ),
//                     Expanded(
//                       flex: tempFeaturedIds.isNotEmpty ? 1 : 2,
//                       child: GestureDetector(
//                         onTap: () {
//                           HapticFeedback.mediumImpact();
//                           setState(() {
//                             _featuredCreatureIds = List.from(tempFeaturedIds);
//                           });
//                           Navigator.pop(context);
//                         },
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           decoration: BoxDecoration(
//                             gradient: LinearGradient(
//                               colors: [
//                                 Colors.indigo.shade600,
//                                 Colors.indigo.shade700,
//                               ],
//                             ),
//                             borderRadius: BorderRadius.circular(12),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.indigo.shade300,
//                                 blurRadius: 8,
//                                 offset: const Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: const Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(Icons.check, color: Colors.white, size: 18),
//                               SizedBox(width: 8),
//                               Text(
//                                 'Apply Changes',
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w700,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     ),
//   );
// }

// void _initializeFeaturedCreatures(
//   List<Map<String, dynamic>> discoveredCreatures,
// ) {
//   if (_featuredCreatureIds.isEmpty && discoveredCreatures.isNotEmpty) {
//     _featuredCreatureIds = discoveredCreatures
//         .take(3)
//         .map((data) => (data['creature'] as Creature).id)
//         .toList();
//   }
// }

// void _showCreatureSelector(List<Map<String, dynamic>> availableCreatures) {
//   List<String> tempFeaturedIds = List.from(_featuredCreatureIds);

//   showModalBottomSheet(
//     context: context,
//     backgroundColor: Colors.transparent,
//     isScrollControlled: true,
//     builder: (context) => StatefulBuilder(
//       builder: (BuildContext context, StateSetter setModalState) {
//         return Container(
//           height: MediaQuery.of(context).size.height * 0.75,
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [Colors.white, Colors.indigo.shade50],
//             ),
//             borderRadius: const BorderRadius.only(
//               topLeft: Radius.circular(24),
//               topRight: Radius.circular(24),
//             ),
//             border: Border.all(color: Colors.indigo.shade300, width: 2),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.indigo.shade200,
//                 blurRadius: 20,
//                 offset: const Offset(0, -4),
//               ),
//             ],
//           ),
//           child: Column(
//             children: [
//               Container(
//                 margin: const EdgeInsets.only(top: 12, bottom: 8),
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: Colors.indigo.shade300,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               Container(
//                 margin: const EdgeInsets.symmetric(
//                   horizontal: 20,
//                   vertical: 12,
//                 ),
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(color: Colors.indigo.shade200, width: 2),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.indigo.shade100,
//                       blurRadius: 8,
//                       offset: const Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             color: Colors.indigo.shade50,
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: Icon(
//                             Icons.science_rounded,
//                             color: Colors.indigo.shade600,
//                             size: 20,
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Text(
//                             'Configure Display Specimens',
//                             style: TextStyle(
//                               color: Colors.indigo.shade800,
//                               fontSize: 16,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 6,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.indigo.shade50,
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: Colors.indigo.shade200),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(
//                             Icons.check_circle,
//                             color: Colors.indigo.shade600,
//                             size: 14,
//                           ),
//                           const SizedBox(width: 6),
//                           Text(
//                             'Selected: ${tempFeaturedIds.length}/3',
//                             style: TextStyle(
//                               color: Colors.indigo.shade700,
//                               fontSize: 13,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Expanded(
//                 child: GridView.builder(
//                   padding: const EdgeInsets.symmetric(horizontal: 20),
//                   physics: const BouncingScrollPhysics(),
//                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                     crossAxisCount: 3,
//                     childAspectRatio: 0.85,
//                     crossAxisSpacing: 12,
//                     mainAxisSpacing: 12,
//                   ),
//                   itemCount: availableCreatures.length,
//                   itemBuilder: (context, index) {
//                     final creatureData = availableCreatures[index];
//                     final creature = creatureData['creature'] as Creature;
//                     final isSelected = tempFeaturedIds.contains(creature.id);
//                     final typeColor = BreedConstants.getTypeColor(
//                       creature.types.first,
//                     );

//                     return GestureDetector(
//                       onTap: () {
//                         HapticFeedback.selectionClick();
//                         setModalState(() {
//                           if (isSelected) {
//                             tempFeaturedIds.remove(creature.id);
//                           } else {
//                             if (tempFeaturedIds.length < 3) {
//                               tempFeaturedIds.add(creature.id);
//                             } else {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                   content: const Text(
//                                     'Maximum 3 specimens allowed',
//                                   ),
//                                   backgroundColor: Colors.orange.shade600,
//                                   duration: const Duration(seconds: 2),
//                                   behavior: SnackBarBehavior.floating,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                               );
//                             }
//                           }
//                         });
//                       },
//                       child: AnimatedContainer(
//                         duration: const Duration(milliseconds: 300),
//                         curve: Curves.easeOutCubic,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                             color: isSelected
//                                 ? Colors.indigo.shade600
//                                 : typeColor.withOpacity(0.3),
//                             width: isSelected ? 3 : 2,
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: isSelected
//                                   ? Colors.indigo.shade300
//                                   : typeColor.withOpacity(0.2),
//                               blurRadius: isSelected ? 12 : 6,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: Stack(
//                           children: [
//                             if (isSelected)
//                               Positioned.fill(
//                                 child: Container(
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(14),
//                                     gradient: RadialGradient(
//                                       colors: [
//                                         Colors.indigo.withOpacity(0.1),
//                                         Colors.transparent,
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             Padding(
//                               padding: const EdgeInsets.all(8),
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Expanded(
//                                     child: Container(
//                                       decoration: BoxDecoration(
//                                         color: typeColor.withOpacity(0.1),
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                       child: ClipRRect(
//                                         borderRadius: BorderRadius.circular(12),
//                                         child: Image.asset(
//                                           'assets/images/${creature.image}',
//                                           fit: BoxFit.contain,
//                                           errorBuilder:
//                                               (context, error, stackTrace) {
//                                                 return Icon(
//                                                   BreedConstants.getTypeIcon(
//                                                     creature.types.first,
//                                                   ),
//                                                   color: typeColor,
//                                                   size: 32,
//                                                 );
//                                               },
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     creature.name,
//                                     style: TextStyle(
//                                       color: Colors.indigo.shade800,
//                                       fontSize: 11,
//                                       fontWeight: FontWeight.w700,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             if (isSelected) ...[
//                               Positioned(
//                                 top: 6,
//                                 right: 6,
//                                 child: Container(
//                                   width: 24,
//                                   height: 24,
//                                   decoration: BoxDecoration(
//                                     color: Colors.indigo.shade600,
//                                     shape: BoxShape.circle,
//                                     boxShadow: [
//                                       BoxShadow(
//                                         color: Colors.indigo.shade300,
//                                         blurRadius: 4,
//                                       ),
//                                     ],
//                                   ),
//                                   child: const Icon(
//                                     Icons.check,
//                                     color: Colors.white,
//                                     size: 16,
//                                   ),
//                                 ),
//                               ),
//                               Positioned(
//                                 top: 6,
//                                 left: 6,
//                                 child: Container(
//                                   width: 20,
//                                   height: 20,
//                                   decoration: BoxDecoration(
//                                     color: Colors.white,
//                                     shape: BoxShape.circle,
//                                     border: Border.all(
//                                       color: Colors.indigo.shade600,
//                                       width: 2,
//                                     ),
//                                   ),
//                                   child: Center(
//                                     child: Text(
//                                       '${tempFeaturedIds.indexOf(creature.id) + 1}',
//                                       style: TextStyle(
//                                         color: Colors.indigo.shade700,
//                                         fontSize: 10,
//                                         fontWeight: FontWeight.w800,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: const BorderRadius.only(
//                     topLeft: Radius.circular(20),
//                     topRight: Radius.circular(20),
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.indigo.shade100,
//                       blurRadius: 12,
//                       offset: const Offset(0, -2),
//                     ),
//                   ],
//                 ),
//                 child: Row(
//                   children: [
//                     if (tempFeaturedIds.isNotEmpty)
//                       Expanded(
//                         child: GestureDetector(
//                           onTap: () {
//                             HapticFeedback.lightImpact();
//                             setModalState(() {
//                               tempFeaturedIds.clear();
//                             });
//                           },
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             margin: const EdgeInsets.only(right: 8),
//                             decoration: BoxDecoration(
//                               color: Colors.grey.shade100,
//                               borderRadius: BorderRadius.circular(12),
//                               border: Border.all(color: Colors.grey.shade300),
//                             ),
//                             child: Text(
//                               'Clear All',
//                               style: TextStyle(
//                                 color: Colors.grey.shade700,
//                                 fontWeight: FontWeight.w700,
//                                 fontSize: 14,
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                           ),
//                         ),
//                       ),
//                     Expanded(
//                       flex: tempFeaturedIds.isNotEmpty ? 1 : 2,
//                       child: GestureDetector(
//                         onTap: () {
//                           HapticFeedback.mediumImpact();
//                           setState(() {
//                             _featuredCreatureIds = List.from(tempFeaturedIds);
//                           });
//                           Navigator.pop(context);
//                         },
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           decoration: BoxDecoration(
//                             gradient: LinearGradient(
//                               colors: [
//                                 Colors.indigo.shade600,
//                                 Colors.indigo.shade700,
//                               ],
//                             ),
//                             borderRadius: BorderRadius.circular(12),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.indigo.shade300,
//                                 blurRadius: 8,
//                                 offset: const Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: const Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(Icons.check, color: Colors.white, size: 18),
//                               SizedBox(width: 8),
//                               Text(
//                                 'Apply Changes',
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w700,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     ),
//   );
// }

// Widget _buildFeaturedCreatures() {
//   return Consumer<GameStateNotifier>(
//     builder: (context, gameState, child) {
//       final discoveredCreatures = gameState.discoveredCreatures;
//       _initializeFeaturedCreatures(discoveredCreatures);

//       return AnimatedBuilder(
//         animation: _glowController,
//         builder: (context, child) {
//           return Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(
//                 color: Colors.indigo.shade300.withOpacity(
//                   0.5 + _glowController.value * 0.5,
//                 ),
//                 width: 2,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.indigo.shade200.withOpacity(
//                     0.3 + _glowController.value * 0.3,
//                   ),
//                   blurRadius: 12 + _glowController.value * 8,
//                   offset: const Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: discoveredCreatures.isEmpty
//                 ? _buildEmptyState()
//                 : _buildCreatureShowcase(discoveredCreatures),
//           );
//         },
//       );
//     },
//   );
// }

// Widget _buildEmptyState() {
//   return Column(
//     children: [
//       AnimatedBuilder(
//         animation: _breathingController,
//         builder: (context, child) {
//           return Transform.scale(
//             scale: 1.0 + (_breathingController.value * 0.08),
//             child: Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.indigo.shade50,
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(color: Colors.indigo.shade200, width: 2),
//               ),
//               child: Icon(
//                 Icons.science_rounded,
//                 size: 48,
//                 color: Colors.indigo.shade600,
//               ),
//             ),
//           );
//         },
//       ),
//       const SizedBox(height: 20),
//       Text(
//         'Research Laboratory Active',
//         style: TextStyle(
//           color: Colors.indigo.shade800,
//           fontSize: 18,
//           fontWeight: FontWeight.w800,
//         ),
//       ),
//       const SizedBox(height: 8),
//       Text(
//         'Begin specimen collection through\ngenetic synthesis and field research',
//         style: TextStyle(
//           color: Colors.indigo.shade600,
//           fontSize: 13,
//           fontWeight: FontWeight.w500,
//           height: 1.4,
//         ),
//         textAlign: TextAlign.center,
//       ),
//     ],
//   );
// }

// Widget _buildCreatureShowcase(List<Map<String, dynamic>> creatures) {
//   final featuredCreatures = _featuredCreatureIds
//       .map(
//         (id) => creatures.firstWhere(
//           (data) => (data['creature'] as Creature).id == id,
//           orElse: () => <String, Object>{},
//         ),
//       )
//       .where((data) => data.isNotEmpty)
//       .toList();

//   while (featuredCreatures.length < 3 &&
//       featuredCreatures.length < creatures.length) {
//     final nextCreature = creatures.firstWhere(
//       (data) =>
//           !_featuredCreatureIds.contains((data['creature'] as Creature).id),
//       orElse: () => <String, Object>{},
//     );
//     if (nextCreature.isNotEmpty) {
//       featuredCreatures.add(nextCreature);
//       _featuredCreatureIds.add((nextCreature['creature'] as Creature).id);
//     } else {
//       break;
//     }
//   }

//   return Column(
//     children: [
//       Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               Icon(
//                 Icons.view_module_rounded,
//                 color: Colors.indigo.shade600,
//                 size: 18,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 'Active Specimens',
//                 style: TextStyle(
//                   color: Colors.indigo.shade800,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w800,
//                 ),
//               ),
//             ],
//           ),
//           GestureDetector(
//             onTap: () {
//               HapticFeedback.lightImpact();
//               _showCreatureSelector(creatures);
//             },
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [Colors.indigo.shade600, Colors.indigo.shade700],
//                 ),
//                 borderRadius: BorderRadius.circular(10),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.indigo.shade300,
//                     blurRadius: 6,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: const Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.edit_rounded, color: Colors.white, size: 14),
//                   SizedBox(width: 6),
//                   Text(
//                     'Configure',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       const SizedBox(height: 20),
//       Row(
//         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//         children: featuredCreatures.asMap().entries.map((entry) {
//           final index = entry.key;
//           final creatureData = entry.value;
//           final creature = creatureData['creature'] as Creature;

//           return _buildEnhancedCreatureSlot(
//             creature,
//             BreedConstants.getTypeColor(creature.types.first),
//             index * 0.3,
//           );
//         }).toList(),
//       ),
//       if (featuredCreatures.length < 3)
//         Padding(
//           padding: const EdgeInsets.only(top: 20),
//           child: GestureDetector(
//             onTap: () {
//               HapticFeedback.lightImpact();
//               _showCreatureSelector(creatures);
//             },
//             child: Container(
//               width: 80,
//               height: 80,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(16),
//                 border: Border.all(
//                   color: Colors.indigo.shade300,
//                   width: 2,
//                   style: BorderStyle.solid,
//                 ),
//                 color: Colors.indigo.shade50,
//               ),
//               child: Icon(
//                 Icons.add_rounded,
//                 color: Colors.indigo.shade600,
//                 size: 32,
//               ),
//             ),
//           ),
//         ),
//     ],
//   );
// }

// Widget _buildEnhancedCreatureSlot(
//   Creature creature,
//   Color glowColor,
//   double delay,
// ) {
//   return AnimatedBuilder(
//     animation: Listenable.merge([_breathingController, _glowController]),
//     builder: (context, child) {
//       final floatOffset = -8 * math.sin(_breathingController.value * math.pi);
//       final scale = 1.0 + (_breathingController.value * 0.05);

//       return Transform.translate(
//         offset: Offset(0, floatOffset),
//         child: Transform.scale(
//           scale: scale,
//           child: GestureDetector(
//             onTap: () {
//               HapticFeedback.mediumImpact();
//               showDialog(
//                 context: context,
//                 builder: (context) => Dialog(
//                   backgroundColor: Colors.transparent,
//                   child: Container(
//                     padding: const EdgeInsets.all(24),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(24),
//                       border: Border.all(
//                         color: glowColor.withOpacity(0.5),
//                         width: 2,
//                       ),
//                       boxShadow: [
//                         BoxShadow(
//                           color: glowColor.withOpacity(0.3),
//                           blurRadius: 20,
//                           offset: const Offset(0, 8),
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(16),
//                           decoration: BoxDecoration(
//                             color: glowColor.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(16),
//                             border: Border.all(
//                               color: glowColor.withOpacity(0.3),
//                               width: 2,
//                             ),
//                           ),
//                           child: ClipRRect(
//                             borderRadius: BorderRadius.circular(12),
//                             child: SizedBox(
//                               width: 180,
//                               height: 180,
//                               child: creature.spriteData != null
//                                   ? CreatureSprite(
//                                       spritePath:
//                                           creature.spriteData!.spriteSheetPath,
//                                       totalFrames:
//                                           creature.spriteData!.totalFrames,
//                                       frameSize: Vector2(
//                                         creature.spriteData!.frameWidth * 1.0,
//                                         creature.spriteData!.frameHeight * 1.0,
//                                       ),
//                                       rows: creature.spriteData!.rows,
//                                       stepTime:
//                                           (creature
//                                               .spriteData!
//                                               .frameDurationMs /
//                                           1000.0),
//                                     )
//                                   : Icon(
//                                       BreedConstants.getTypeIcon(
//                                         creature.types.first,
//                                       ),
//                                       color: glowColor,
//                                       size: 64,
//                                     ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//                         Text(
//                           creature.name,
//                           style: TextStyle(
//                             color: Colors.indigo.shade800,
//                             fontSize: 20,
//                             fontWeight: FontWeight.w800,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 6,
//                           ),
//                           decoration: BoxDecoration(
//                             color: glowColor.withOpacity(0.15),
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(
//                               color: glowColor.withOpacity(0.4),
//                             ),
//                           ),
//                           child: Text(
//                             creature.types.first,
//                             style: TextStyle(
//                               color: glowColor,
//                               fontSize: 13,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 20),
//                         GestureDetector(
//                           onTap: () {
//                             HapticFeedback.lightImpact();
//                             Navigator.pop(context);
//                           },
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 24,
//                               vertical: 12,
//                             ),
//                             decoration: BoxDecoration(
//                               gradient: LinearGradient(
//                                 colors: [
//                                   Colors.indigo.shade600,
//                                   Colors.indigo.shade700,
//                                 ],
//                               ),
//                               borderRadius: BorderRadius.circular(12),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.indigo.shade300,
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 2),
//                                 ),
//                               ],
//                             ),
//                             child: const Text(
//                               'Close',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.w700,
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               );
//             },
//             child: Container(
//               width: 80,
//               height: 80,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(16),
//                 border: Border.all(color: glowColor.withOpacity(0.6), width: 3),
//                 boxShadow: [
//                   BoxShadow(
//                     color: glowColor.withOpacity(
//                       0.3 + _glowController.value * 0.4,
//                     ),
//                     blurRadius: 12 + _glowController.value * 12,
//                     offset: const Offset(0, 4),
//                     spreadRadius: _glowController.value * 4,
//                   ),
//                 ],
//               ),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(13),
//                 child: creature.spriteData != null
//                     ? CreatureSprite(
//                         spritePath: creature.spriteData!.spriteSheetPath,
//                         rows: creature.spriteData!.rows,
//                         totalFrames: creature.spriteData!.totalFrames,
//                         frameSize: Vector2(
//                           creature.spriteData!.frameWidth * 1.0,
//                           creature.spriteData!.frameHeight * 1.0,
//                         ),
//                         stepTime:
//                             (creature.spriteData!.frameDurationMs / 1000.0),
//                       )
//                     : Icon(
//                         BreedConstants.getTypeIcon(creature.types.first),
//                         size: 36,
//                         color: glowColor,
//                       ),
//               ),
//             ),
//           ),
//         ),
//       );
//     },
//   );
// }
