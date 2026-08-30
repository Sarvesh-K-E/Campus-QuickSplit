import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_card.dart';

class P2PReceiveScreen extends StatefulWidget {
  const P2PReceiveScreen({super.key});

  @override
  State<P2PReceiveScreen> createState() => _P2PReceiveScreenState();
}

class _P2PReceiveScreenState extends State<P2PReceiveScreen> {
  final Strategy strategy = Strategy.P2P_STAR;
  bool _isProcessing = false;
  final MobileScannerController _cameraController = MobileScannerController();
  String _status = 'Scan the sender\'s QR code';
  String? _targetEndpointName;

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final code = barcodes.first.rawValue;
    if (code == null || !code.startsWith('CQS_')) return; // Validate QR content

    setState(() {
      _isProcessing = true;
      _targetEndpointName = code;
      _status = 'Connecting to sender...';
    });
    
    // Stop camera completely to avoid loops
    await _cameraController.stop();

    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    try {
      await [
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
        Permission.nearbyWifiDevices,
      ].request();

      setState(() => _status = 'Looking for nearby device...');

      final bool discovering = await Nearby().startDiscovery(
        _targetEndpointName!,
        strategy,
        onEndpointFound: (String id, String name, String serviceId) async {
          if (name == _targetEndpointName) {
            setState(() => _status = 'Found device! Requesting connection...');
            // Found the right device, request connection
            Nearby().stopDiscovery();
            await Nearby().requestConnection(
              'Receiver',
              id,
              onConnectionInitiated: (id, info) async {
                setState(() => _status = 'Accepting connection...');
                await Nearby().acceptConnection(
                  id,
                  onPayLoadRecieved: (endpointId, payload) {
                    if (payload.type == PayloadType.BYTES) {
                      setState(() => _status = 'Data received! Importing...');
                      final jsonStr = utf8.decode(payload.bytes!);
                      if (mounted) {
                        context.pushReplacement('/import_group', extra: jsonStr);
                      }
                    }
                  },
                  onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
                );
              },
              onConnectionResult: (id, status) {
                if (status == Status.CONNECTED) {
                  setState(() => _status = 'Connected! Waiting for data...');
                } else {
                  setState(() => _status = 'Connection failed.');
                }
              },
              onDisconnected: (id) {
                setState(() {
                  if (_status != 'Data received! Importing...') {
                    _status = 'Disconnected from sender.';
                  }
                });
              },
            );
          }
        },
        onEndpointLost: (String? id) {},
      );

      if (!discovering) {
        setState(() => _status = 'Failed to start Bluetooth discovery.');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Group', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Stack(
        children: [
          if (!_isProcessing)
            MobileScanner(
              controller: _cameraController,
              onDetect: _handleBarcode,
            ),
          
          // Dark overlay when processing
          if (_isProcessing)
            Container(
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.8)),
            ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isProcessing)
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.neoYellow, width: 4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  )
                else
                  NeoCard(
                    color: AppTheme.neoBlue,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppTheme.neoYellow),
                          const SizedBox(height: 24),
                          const Text('Bluetooth Transfer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                          const SizedBox(height: 8),
                          Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                
                if (!_isProcessing) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _status,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  )
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
