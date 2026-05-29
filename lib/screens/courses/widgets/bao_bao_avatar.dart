// import 'package:flutter/material.dart';

// class BaoBaoAvatar extends StatelessWidget {
//   final double size;
//   final bool showSparkle;

//   const BaoBaoAvatar({
//     super.key,
//     this.size = 52,
//     this.showSparkle = true,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: size,
//       height: size,
//       child: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           CustomPaint(
//             size: Size(size, size),
//             painter: _BaoBaoPlushPandaPainter(),
//           ),

//           if (showSparkle)
//             Positioned(
//               right: -2,
//               top: -2,
//               child: Container(
//                 width: size * 0.34,
//                 height: size * 0.34,
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFF3E8FF),
//                   shape: BoxShape.circle,
//                   boxShadow: [
//                     BoxShadow(
//                       color: const Color(0xFF7E3291).withValues(alpha: 0.16),
//                       blurRadius: 8,
//                       offset: const Offset(0, 3),
//                     ),
//                   ],
//                 ),
//                 child: Icon(
//                   Icons.auto_awesome_rounded,
//                   size: size * 0.19,
//                   color: const Color(0xFF7E3291),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// class _BaoBaoPlushPandaPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final s = size.width;

//     final shadowPaint = Paint()
//       ..color = Colors.black.withValues(alpha: 0.08)
//       ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

//     final furWhite = Paint()
//       ..color = const Color(0xFFFFFEFA)
//       ..style = PaintingStyle.fill;

//     final furCream = Paint()
//       ..color = const Color(0xFFF8F5EF)
//       ..style = PaintingStyle.fill;

//     final darkFur = Paint()
//       ..color = const Color(0xFF5A5353)
//       ..style = PaintingStyle.fill;

//     final darkerFur = Paint()
//       ..color = const Color(0xFF3E3A3A)
//       ..style = PaintingStyle.fill;

//     final blackPaint = Paint()
//       ..color = const Color(0xFF111827)
//       ..style = PaintingStyle.fill;

//     final vestPaint = Paint()
//       ..color = const Color(0xFF3F4A3F)
//       ..style = PaintingStyle.fill;

//     final vestDarkPaint = Paint()
//       ..color = const Color(0xFF263126)
//       ..style = PaintingStyle.fill;

//     final borderPaint = Paint()
//       ..color = const Color(0xFFE9D5FF)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = s * 0.025;

//     // Soft background circle
//     canvas.drawCircle(
//       Offset(s * 0.50, s * 0.53),
//       s * 0.48,
//       Paint()..color = const Color(0xFFF3E8FF),
//     );

//     // Shadow
//     canvas.drawOval(
//       Rect.fromCenter(
//         center: Offset(s * 0.50, s * 0.87),
//         width: s * 0.58,
//         height: s * 0.13,
//       ),
//       shadowPaint,
//     );

//     // Body
//     canvas.drawOval(
//       Rect.fromCenter(
//         center: Offset(s * 0.50, s * 0.72),
//         width: s * 0.58,
//         height: s * 0.48,
//       ),
//       furWhite,
//     );

//     // Arms
//     canvas.save();
//     canvas.translate(s * 0.25, s * 0.69);
//     canvas.rotate(-0.55);
//     canvas.drawOval(
//       Rect.fromCenter(
//         center: Offset.zero,
//         width: s * 0.18,
//         height: s * 0.34,
//       ),
//       darkFur,
//     );
//     canvas.restore();

//     canvas.save();
//     canvas.translate(s * 0.75, s * 0.69);
//     canvas.rotate(0.55);
//     canvas.drawOval(
//       Rect.fromCenter(
//         center: Offset.zero,
//         width: s * 0.18,
//         height: s * 0.34,
//       ),
//       darkFur,
//     );
//     canvas.restore();

//     // Ears
//     canvas.drawCircle(
//       Offset(s * 0.27, s * 0.22),
//       s * 0.15,
//       darkFur,
//     );
//     canvas.drawCircle(
//       Offset(s * 0.73, s * 0.22),
//       s * 0.15,
//       darkFur,
//     );

//     // Head
//     canvas.drawOval(
//       Rect.fromCenter(
//         center: Offset(s * 0.50, s * 0.43),
//         width: s * 0.68,
//         height: s * 0.64,
//       ),
//       furWhite,
//     );

//     // Face soft cream center
//     canvas.drawOval(
//       Rect.fromCenter(
//         center: Offset(s * 0.50, s * 0.48),
//         width: s * 0.48,
//         height: s * 0.40,
//       ),
//       furCream,
//     );

//     // Head border
//     canvas.drawOval(
//       Rect.fromCenter(
//         center: Offset(s * 0.50, s * 0.43),
//         width: s * 0.68,
//         height: s * 0.64,
//       ),
//       borderPaint,
//     );

//     // Eye patches
//     canvas.save();
//     canvas.translate(s * 0.36, s * 0.42);
//     canvas.rotate(-0.32);
//     canvas.drawOval(
//       Rect.fromCenter(
//         center: Offset.zero,
//         width: s * 0.18,
//         height: s * 0.27,
//       ),
//       darkFur,
//     );
//     canvas.restore();

//     canvas.save();
//     canvas.translate(s * 0.64, s * 0.42);
//     canvas.rotate(0.32);
//     canvas.drawOval(
//       Rect.fromCenter(
//         center: Offset.zero,
//         width: s * 0.18,
//         height: s * 0.27,
//       ),
//       darkFur,
//     );
//     canvas.restore();

//     // Eyes  
//     canvas.drawCircle(
//       Offset(s * 0.38, s * 0.42),
//       s * 0.042,
//       blackPaint,
//     );
//     canvas.drawCircle(
//       Offset(s * 0.62, s * 0.42),
//       s * 0.042,
//       blackPaint,
//     );

//     // Eye highlight
//     canvas.drawCircle(
//       Offset(s * 0.395, s * 0.405),
//       s * 0.012,
//       Paint()..color = Colors.white,
//     );
//     canvas.drawCircle(
//       Offset(s * 0.635, s * 0.405),
//       s * 0.012,
//       Paint()..color = Colors.white,
//     );

//     // Nose
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(
//         Rect.fromCenter(
//           center: Offset(s * 0.50, s * 0.53),
//           width: s * 0.13,
//           height: s * 0.09,
//         ),
//         Radius.circular(s * 0.04),
//       ),
//       blackPaint,
//     );

//     // Mouth seam
//     final seamPaint = Paint()
//       ..color = const Color(0xFF111827)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = s * 0.015
//       ..strokeCap = StrokeCap.round;

//     canvas.drawLine(
//       Offset(s * 0.50, s * 0.575),
//       Offset(s * 0.50, s * 0.65),
//       seamPaint,
//     );

//     final leftMouth = Path()
//       ..moveTo(s * 0.50, s * 0.61)
//       ..quadraticBezierTo(s * 0.46, s * 0.66, s * 0.42, s * 0.62);

//     final rightMouth = Path()
//       ..moveTo(s * 0.50, s * 0.61)
//       ..quadraticBezierTo(s * 0.54, s * 0.66, s * 0.58, s * 0.62);

//     canvas.drawPath(leftMouth, seamPaint);
//     canvas.drawPath(rightMouth, seamPaint);

//     // Small vest on chest, inspired by the plush
//     final vestPath = Path()
//       ..moveTo(s * 0.34, s * 0.68)
//       ..lineTo(s * 0.66, s * 0.68)
//       ..lineTo(s * 0.72, s * 0.88)
//       ..quadraticBezierTo(s * 0.50, s * 0.94, s * 0.28, s * 0.88)
//       ..close();

//     canvas.drawPath(vestPath, vestPaint);

//     final vestPocket = RRect.fromRectAndRadius(
//       Rect.fromLTWH(s * 0.39, s * 0.74, s * 0.22, s * 0.10),
//       Radius.circular(s * 0.025),
//     );

//     canvas.drawRRect(vestPocket, vestDarkPaint);

//     final textPaint = TextPainter(
//       text: TextSpan(
//         text: 'NTHU',
//         style: TextStyle(
//           color: Colors.white.withValues(alpha: 0.92),
//           fontSize: s * 0.075,
//           fontWeight: FontWeight.w900,
//           letterSpacing: 0.3,
//         ),
//       ),
//       textDirection: TextDirection.ltr,
//       textAlign: TextAlign.center,
//     )..layout(maxWidth: s * 0.24);

//     textPaint.paint(
//       canvas,
//       Offset(s * 0.39, s * 0.765),
//     );

//     // Plush fur texture dots / strokes
//     final texturePaint = Paint()
//       ..color = Colors.black.withValues(alpha: 0.045)
//       ..strokeWidth = s * 0.006
//       ..strokeCap = StrokeCap.round;

//     final texturePoints = <Offset>[
//       Offset(s * 0.42, s * 0.22),
//       Offset(s * 0.50, s * 0.18),
//       Offset(s * 0.58, s * 0.24),
//       Offset(s * 0.30, s * 0.47),
//       Offset(s * 0.70, s * 0.49),
//       Offset(s * 0.43, s * 0.70),
//       Offset(s * 0.56, s * 0.72),
//       Offset(s * 0.48, s * 0.34),
//     ];

//     for (final p in texturePoints) {
//       canvas.drawLine(
//         p,
//         Offset(p.dx + s * 0.025, p.dy + s * 0.01),
//         texturePaint,
//       );
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) {
//     return false;
//   }
// }