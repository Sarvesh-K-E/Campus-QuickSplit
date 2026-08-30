import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/settlement_service.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_card.dart';

class OptimizationGraphScreen extends StatefulWidget {
  final String groupId;

  const OptimizationGraphScreen({super.key, required this.groupId});

  @override
  State<OptimizationGraphScreen> createState() => _OptimizationGraphScreenState();
}

class _OptimizationGraphScreenState extends State<OptimizationGraphScreen> {
  bool _showOptimized = true;

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final group = dataProvider.groups.firstWhere((g) => g.id == widget.groupId);
    final expenses = dataProvider.allExpenses.where((e) => e.groupId == group.id).toList();

    // Calculate both
    final unoptimized = SettlementService.getUnoptimizedDebts(group, expenses);
    
    final balances = SettlementService.calculateBalances(group, expenses);
    final optimized = SettlementService.simplifyDebts(balances);

    final transactionsToDraw = _showOptimized ? optimized : unoptimized;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Optimization Graph', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: NeoCard(
              color: AppTheme.neoBlue,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Transaction Path Visualization',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _showOptimized = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_showOptimized ? AppTheme.neoPink : Colors.white,
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: Center(
                                child: Text('Raw (${unoptimized.length})', style: const TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _showOptimized = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _showOptimized ? AppTheme.neoGreen : Colors.white,
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: Center(
                                child: Text('Optimized (${optimized.length})', style: const TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _showOptimized 
                          ? 'Showing the minimized smart path to settle all debts.' 
                          : 'Showing the original tangled web of direct peer-to-peer debts.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CustomPaint(
                painter: GraphPainter(
                  members: group.members,
                  transactions: transactionsToDraw,
                  isOptimized: _showOptimized,
                  context: context,
                ),
                child: Container(),
              ),
            ),
          ),
          const Divider(thickness: 3, color: Colors.black, height: 1),
          Container(
            color: _showOptimized ? AppTheme.neoGreen : AppTheme.neoPink,
            padding: const EdgeInsets.symmetric(vertical: 8),
            width: double.infinity,
            child: Text(
              'TRANSACTIONS',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2),
            ),
          ),
          const Divider(thickness: 3, color: Colors.black, height: 1),
          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: transactionsToDraw.length,
              itemBuilder: (context, index) {
                final tx = transactionsToDraw[index];
                final fromUser = group.members.firstWhere((m) => m.id == tx.from, orElse: () => User(id: '', name: 'Unknown', isLocal: false));
                final toUser = group.members.firstWhere((m) => m.id == tx.to, orElse: () => User(id: '', name: 'Unknown', isLocal: false));
                
                return Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: const Icon(Icons.arrow_forward_rounded, color: Colors.black),
                    title: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Outfit'),
                        children: [
                          TextSpan(text: fromUser.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                          const TextSpan(text: ' owes ', style: TextStyle(fontWeight: FontWeight.w500)),
                          TextSpan(text: toUser.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    trailing: Text(
                      '₹${tx.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<User> members;
  final List<Transaction> transactions;
  final bool isOptimized;
  final BuildContext context;

  GraphPainter({
    required this.members,
    required this.transactions,
    required this.isOptimized,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (members.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 40; // leave padding for nodes

    Map<String, Offset> nodePositions = {};
    
    // Position nodes in a circle
    double angleStep = (2 * pi) / members.length;
    for (int i = 0; i < members.length; i++) {
      double angle = i * angleStep - (pi / 2); // Start at top
      double x = center.dx + radius * cos(angle);
      double y = center.dy + radius * sin(angle);
      nodePositions[members[i].id] = Offset(x, y);
    }

    // Draw edges
    final edgePaint = Paint()
      ..color = isOptimized ? AppTheme.neoGreen : AppTheme.neoPink
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = isOptimized ? AppTheme.neoGreen : AppTheme.neoPink
      ..style = PaintingStyle.fill;

    for (var tx in transactions) {
      final start = nodePositions[tx.from];
      final end = nodePositions[tx.to];
      
      if (start == null || end == null) continue;

      final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final dist = sqrt(dx*dx + dy*dy);
      
      if (dist < 0.1) continue;
      
      final nx = -dy / dist;
      final ny = dx / dist;
      
      bool hasReverseEdge = transactions.any((t) => t.from == tx.to && t.to == tx.from);
      double curveFactor = hasReverseEdge ? 40.0 : 0.0;
      final controlPoint = Offset(midPoint.dx + nx * curveFactor, midPoint.dy + ny * curveFactor);

      final path = Path();
      path.moveTo(start.dx, start.dy);
      path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, end.dx, end.dy);
      canvas.drawPath(path, edgePaint);

      final dirX = end.dx - controlPoint.dx;
      final dirY = end.dy - controlPoint.dy;
      final dirLen = sqrt(dirX*dirX + dirY*dirY);
      if (dirLen < 0.1) continue;
      
      final udx = dirX / dirLen;
      final udy = dirY / dirLen;

      final arrowEnd = Offset(end.dx - udx * 25, end.dy - udy * 25);
      
      final arrowSize = 12.0;
      final leftWing = Offset(
        arrowEnd.dx - udx * arrowSize - udy * (arrowSize/1.5),
        arrowEnd.dy - udy * arrowSize + udx * (arrowSize/1.5)
      );
      final rightWing = Offset(
        arrowEnd.dx - udx * arrowSize + udy * (arrowSize/1.5),
        arrowEnd.dy - udy * arrowSize - udx * (arrowSize/1.5)
      );

      final arrowPath = Path()
        ..moveTo(arrowEnd.dx, arrowEnd.dy)
        ..lineTo(leftWing.dx, leftWing.dy)
        ..lineTo(rightWing.dx, rightWing.dy)
        ..close();

      canvas.drawPath(arrowPath, arrowPaint);

    }

    Map<String, String> nodeLabels = {};
    for (var member in members) {
      if (member.name.isEmpty) {
        nodeLabels[member.id] = '?';
        continue;
      }
      String label = member.name[0].toUpperCase();
      int chars = 1;
      
      while (chars < member.name.length && members.any((m) => m.id != member.id && m.name.toUpperCase().startsWith(label))) {
        chars++;
        label = member.name.substring(0, chars).toUpperCase();
      }
      
      if (chars > 3 && member.name.contains(' ')) {
        var parts = member.name.trim().split(' ');
        if (parts.length > 1 && parts.last.isNotEmpty) {
          label = (parts.first[0] + parts.last[0]).toUpperCase();
        }
      }
      
      if (label.length > 4) label = label.substring(0, 4);
      nodeLabels[member.id] = label;
    }

    final nodeBgPaint = Paint()..color = AppTheme.neoYellow;
    final nodeBorderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 3;

    for (int i = 0; i < members.length; i++) {
      final pos = nodePositions[members[i].id]!;
      
      canvas.drawCircle(pos, 26, nodeBgPaint);
      canvas.drawCircle(pos, 26, nodeBorderPaint);
      
      final label = nodeLabels[members[i].id]!;
      double fontSize = 18.0;
      if (label.length == 3) fontSize = 14.0;
      if (label.length >= 4) fontSize = 12.0;

      final textPainter = TextPainter(
        text: TextSpan(
          text: label, 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: fontSize)
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainter.paint(
        canvas, 
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2)
      );
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.isOptimized != isOptimized ||
           oldDelegate.members != members ||
           oldDelegate.transactions != transactions;
  }
}
