import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_button.dart';
import '../widgets/neo_card.dart';

class ReceivePaymentScreen extends StatefulWidget {
  const ReceivePaymentScreen({super.key});

  @override
  State<ReceivePaymentScreen> createState() => _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState extends State<ReceivePaymentScreen> {
  final _qrKey = GlobalKey();
  Map<String, dynamic>? _selectedSettlement;

  Future<void> _shareQR() async {
    final user = Provider.of<DataProvider>(context, listen: false).localUser;
    if (user?.upiId == null || user!.upiId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please save a valid UPI ID in your Profile first')));
      return;
    }

    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/upi_qr.png').create();
      await file.writeAsBytes(pngBytes);

      String text = 'Here is my UPI QR code.';
      if (_selectedSettlement != null) {
        final amount = _selectedSettlement!['amount'] as double;
        final payerName = _selectedSettlement!['payerName'] as String;
        text = 'Hey $payerName, please pay back ₹${amount.toStringAsFixed(2)} using this QR code!';
      }

      await Share.shareXFiles([XFile(file.path)], text: text);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating QR image: $e')));
    }
  }

  String _getUpiUrl(String upiId, String name) {
    String url = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}';
    if (_selectedSettlement != null) {
      final amount = _selectedSettlement!['amount'] as double;
      url += '&am=${amount.toStringAsFixed(2)}&cu=INR';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final user = dataProvider.localUser;
    final pendingSettlements = dataProvider.getPendingIncomingSettlements();
    final hasUpi = user?.upiId != null && user!.upiId!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Payments'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // QR Code Section
            if (hasUpi) ...[
              Center(
                child: RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white, // Always white for best QR scanning
                      border: Border.all(color: Colors.black, width: 4),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(6, 6))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: _getUpiUrl(user!.upiId!, user.name.replaceAll(' (You)', '')),
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                          embeddedImage: const AssetImage('assets/icon.png'),
                          embeddedImageStyle: const QrEmbeddedImageStyle(
                            size: Size(40, 40),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.upiId!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                        ),
                        if (_selectedSettlement != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.neoYellow,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Text(
                              '₹${(_selectedSettlement!['amount'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              NeoButton(
                color: AppTheme.neoBlue,
                onPressed: _shareQR,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share, color: Colors.black),
                    SizedBox(width: 8),
                    Text('SHARE QR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.neoOrange,
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.black),
                    const SizedBox(height: 12),
                    const Text(
                      'No UPI ID Found',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set your UPI ID in your Profile to generate QR codes for payments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 48),

            // Pending Settlements List
            const Text('PENDING SETTLEMENTS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            
            if (pendingSettlements.isNotEmpty)
              ...pendingSettlements.map((settlement) {
                final isSelected = _selectedSettlement != null && 
                                   _selectedSettlement!['groupId'] == settlement['groupId'] && 
                                   _selectedSettlement!['payerId'] == settlement['payerId'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: hasUpi ? () {
                      setState(() {
                        _selectedSettlement = isSelected ? null : settlement;
                      });
                    } : null,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.neoYellow : Theme.of(context).scaffoldBackgroundColor,
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(isSelected ? 2 : 4, isSelected ? 2 : 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(settlement['payerName'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(settlement['groupName'], style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Text(
                            '₹${(settlement['amount'] as double).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              })
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border.all(color: Colors.grey.shade400, width: 2, style: BorderStyle.solid),
                ),
                child: const Center(
                  child: Text(
                    'No pending incoming settlements.',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
