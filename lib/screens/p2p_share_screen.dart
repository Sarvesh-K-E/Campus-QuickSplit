import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_card.dart';

class P2PShareScreen extends StatefulWidget {
  final String groupId;

  const P2PShareScreen({super.key, required this.groupId});

  @override
  State<P2PShareScreen> createState() => _P2PShareScreenState();
}

class _P2PShareScreenState extends State<P2PShareScreen> {
  final Strategy strategy = Strategy.P2P_STAR;
  String _endpointName = '';
  bool _isAdvertising = false;
  String? _error;
  String _status = 'Initializing...';
  String? _connectedEndpointId;

  @override
  void initState() {
    super.initState();
    _endpointName = 'CQS_${Random().nextInt(1000000).toString().padLeft(6, '0')}';
    _startSharing();
  }

  Future<void> _startSharing() async {
    try {
      // Request all necessary permissions
      await [
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
        Permission.nearbyWifiDevices,
      ].request();

      setState(() => _status = 'Starting broadcast...');
      
      final bool advertising = await Nearby().startAdvertising(
        _endpointName,
        strategy,
        onConnectionInitiated: (String id, ConnectionInfo info) async {
          setState(() => _status = 'Connection requested by receiver...');
          // Automatically accept connection
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {},
            onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {
              if (payloadTransferUpdate.status == PayloadStatus.SUCCESS) {
                setState(() => _status = 'Data sent successfully!');
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) Navigator.pop(context);
                });
              }
            },
          );
        },
        onConnectionResult: (String id, Status status) async {
          if (status == Status.CONNECTED) {
            setState(() {
              _connectedEndpointId = id;
              _status = 'Connected! Sending group data...';
            });
            // Send the JSON payload
            final dataProvider = Provider.of<DataProvider>(context, listen: false);
            final jsonStr = await dataProvider.exportGroupAsJsonString(widget.groupId);
            await Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(jsonStr)));
          } else {
            setState(() => _status = 'Connection failed.');
          }
        },
        onDisconnected: (String id) {
          setState(() {
            if (_status != 'Data sent successfully!') {
              _status = 'Receiver disconnected.';
            }
          });
        },
      );

      if (advertising) {
        setState(() {
          _isAdvertising = true;
          _status = 'Waiting for receiver to scan...';
        });
      } else {
        setState(() => _error = 'Failed to start advertising.');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }
  }

  @override
  void dispose() {
    if (_isAdvertising) {
      Nearby().stopAdvertising();
    }
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Group', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _error != null
            ? NeoCard(
                color: AppTheme.neoPink,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.black),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NeoCard(
                    color: AppTheme.neoYellow,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Text(
                            'Scan to Receive',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Have your friend tap "Receive Group" and scan this QR code.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 32),
                          if (_isAdvertising)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.black, width: 4),
                              ),
                              child: QrImageView(
                                data: _endpointName, // We share the Nearby Endpoint Name!
                                version: QrVersions.auto,
                                size: 220,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                              ),
                            )
                          else
                            const SizedBox(
                              height: 220,
                              child: Center(child: CircularProgressIndicator(color: AppTheme.neoPink)),
                            ),
                          const SizedBox(height: 24),
                          Text(_status, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.neoBlue)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
