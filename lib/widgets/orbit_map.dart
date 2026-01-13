import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gift.dart';
import '../theme/app_theme.dart';

import '../models/guest.dart';

class OrbitMap extends StatefulWidget {
  final String category;
  final List<Gift> gifts;
  final Map<int, Guest> guestMap;
  final VoidCallback onClose;

  const OrbitMap({
    super.key,
    required this.category,
    required this.gifts,
    required this.guestMap,
    required this.onClose,
  });

  @override
  State<OrbitMap> createState() => _OrbitMapState();
}

class _OrbitMapState extends State<OrbitMap> with SingleTickerProviderStateMixin {
  int? _activeNodeIndex;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '婚礼': return Icons.favorite_rounded;
      case '满月': return Icons.child_care_rounded;
      case '乔迁': return Icons.home_rounded;
      case '生日': return Icons.cake_rounded;
      case '丧事': return Icons.sentiment_dissatisfied_rounded;
      case '过年': return Icons.celebration_rounded;
      default: return Icons.card_giftcard_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 计算总金额
    double totalAmount = 0;
    for (var g in widget.gifts) {
      if (g.isReceived) {
        totalAmount += g.amount;
      } else {
        totalAmount -= g.amount; // 或者是绝对值相加？React代码里是 abs(received + given) 如果 given 是存的负数的话..
      }
      // React代码: Math.abs(cat.received + cat.given). 但在我的 CategoryData 中 logic 是分开存正数的
      // 让我们仔细看 React: map[r.category].given -= r.amount; 所以 given 是负数.
      // 这里的 gifts 列表里 amount 都是正数，isReceived 区分方向.
      // 简单起见，这里展示总流动金额 (received + given)
    }
    double flowAmount = widget.gifts.fold(0, (sum, g) => sum + g.amount);

    return SizedBox(
      height: 400,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 轨道圈 (Background Rings)
          Container(
            width: 160, // 80 * 2
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            ),
          ),
          Container(
            width: 240, // 120 * 2
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            ),
          ),

          // 中心连线 (Connecting Lines)
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(400, 400),
              painter: OrbitLinesPainter(
                gifts: widget.gifts,
                centerColor: AppTheme.primaryColor,
              ),
            ),
          ),


          // 中心枢纽 (Center Hub)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Pulse Effect
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 100 + (_pulseController.value * 20),
                        height: 100 + (_pulseController.value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6366F1).withOpacity(0.1 * (1 - _pulseController.value)),
                        ),
                      );
                    },
                  ),
                    // Main Circle
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    child: Center(
                      child: Icon(
                        _getCategoryIcon(widget.category),
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  // Close Button
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface, // Adaptive surface
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            )
                          ]
                        ),
                        child: Icon(Icons.close, size: 16, color: Theme.of(context).iconTheme.color?.withOpacity(0.7)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.category}往来',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '¥${flowAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '共 ${widget.gifts.length} 条记录',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // 卫星节点 (Satellites) - 限制最多显示 12 个
          ...(() {
            final maxNodes = 12;
            final displayGifts = widget.gifts.take(maxNodes).toList();
            final displayCount = displayGifts.length;
            
            return List.generate(displayCount, (index) {
              final gift = displayGifts[index];
              final angle = (index * (360 / displayCount)) * (math.pi / 180);
              final radius = gift.isReceived ? 80.0 : 120.0; // 收礼内圈，送礼外圈
              final x = math.cos(angle) * radius;
              final y = math.sin(angle) * radius;
              final isSelected = _activeNodeIndex == index;
              
              final color = gift.isReceived 
                  ? const Color(0xFF6366F1) // Indigo
                  : const Color(0xFFF43F5E); // Rose

            return Positioned(
              // Center is at 225, 225 (half of 450)
              // But strictly speaking in Stack alignment center, we use translation
              child: Transform.translate(
                offset: Offset(x, y),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeNodeIndex = isSelected ? null : index;
                    });
                  },
                  child: AnimatedScale(
                    scale: isSelected ? 1.25 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tooltip (Top)
                        AnimatedOpacity(
                          opacity: isSelected ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Text(
                              '${gift.date.month}/${gift.date.day} · ${gift.note ?? '记录'}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Node Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: gift.isReceived 
                                ? const Color(0xFF1E1B4B) // Indigo 950
                                : const Color(0xFF4C0519), // Rose 950
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.2),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: color.withOpacity(0.8),
                            size: 20,
                          ),
                        ),
                        // Info Text (Bottom)
                        AnimatedOpacity(
                          opacity: isSelected ? 1.0 : 0.6,
                          duration: const Duration(milliseconds: 300),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                Text(
                                  widget.guestMap[gift.guestId]?.name ?? '未知客人',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '¥${gift.amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          });
        })(),
        ],
      ),
    );
  }
}

class OrbitLinesPainter extends CustomPainter {
  final List<Gift> gifts;
  final Color centerColor;

  OrbitLinesPainter({
    required this.gifts,
    required this.centerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    final maxNodes = 12;
    final displayCount = gifts.length > maxNodes ? maxNodes : gifts.length;

    for (var i = 0; i < displayCount; i++) {
      final gift = gifts[i];
      final angle = (i * (360 / displayCount)) * (math.pi / 180);
      final radius = gift.isReceived ? 80.0 : 120.0;
      
      // Calculate end point (center of the node)
      final endX = center.dx + math.cos(angle) * radius;
      final endY = center.dy + math.sin(angle) * radius;
      
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      
      // Gradient line
      final rect = Rect.fromPoints(center, Offset(endX, endY));
      paint.shader = LinearGradient(
        colors: [
           gift.isReceived ? const Color(0xFF6366F1) : const Color(0xFFF43F5E).withOpacity(0.3),
           Colors.transparent,
        ],
        stops: const [0.0, 1.0],
        begin: Alignment.centerLeft, // This needs adjustment based on angle, but simple gradient works ok for radial feel if tailored
        // Alternatively, use a radial gradient or just simple color transition
      ).createShader(rect);

      // Simple solid line with opacity for now better visual control
      paint.shader = null;
      paint.color = gift.isReceived 
          ? const Color(0xFF6366F1).withOpacity(0.3)
          : const Color(0xFFF43F5E).withOpacity(0.15);

      canvas.drawLine(center, Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant OrbitLinesPainter oldDelegate) {
     return oldDelegate.gifts != gifts;
  }
}
