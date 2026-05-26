import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

main() {
  runApp(const ChessVoiceApp());
}

class ChessVoiceApp extends StatelessWidget {
  const ChessVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Xadrez por Voz",
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BleSetupScreen(),
    );
  }
}

class BleSetupScreen extends StatefulWidget {
  const BleSetupScreen({super.key});

  @override
  State<BleSetupScreen> createState() => _BleSetupScreenState();
}

class _BleSetupScreenState extends State<BleSetupScreen> {
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _chessCharacteristic;
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  final Guid chessServiceUuid = Guid("A07498CA-AD5B-474E-940D-16F1FBE7E8CD");
  final Guid chessCharacteristicUuid = Guid("51FF12BB-3ED8-46E5-B4F9-D64E2FEC021B");

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      setState(() {
        _isScanning = state;
      });
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestBluetoothPermissions() async {
    if (!Platform.isAndroid) return;

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _handleBleSetup() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true) {
      try {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
        _showDeviceSelectionDialog();
      } catch (e) {
        _showSnackBar("Erro ao iniciar escaneamento: $e");
      }
    } else {
      _showSnackBar("Permissões de Bluetooth negadas.");
    }
  }

  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Selecione o ESP32"),
          content: StatefulBuilder(
            builder: (context, setModalState) {
              return SizedBox(
                width: double.maxFinite,
                height: 300,
                child: _scanResults.isEmpty
                  ? const Center(child: Text("Buscando dispositivos..."))
                  : ListView.builder(
                    itemCount: _scanResults.length,
                    itemBuilder: (context, index) {
                      final result = _scanResults[index];
                      return ListTile(
                        leading: const Icon(Icons.bluetooth, color: Colors.blue),
                        title: Text(result.device.platformName),
                        subtitle: Text(result.device.remoteId.str),
                        trailing: Text("${result.rssi} dBm"),
                        onTap: () {
                          Navigator.of(context).pop();
                          _connectToDevice(result.device);
                        },
                      );
                    },
                  ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                FlutterBluePlus.stopScan();
                Navigator.of(context).pop();
              },
              child: const Text("Cancelar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _showSnackBar("Conectando a ${device.platformName}...");

    try {
      await device.connect(license: License.free);

      setState(() {
        _connectedDevice = device;
      });

      _showSnackBar("Conectado com sucesso!");

      final services = await device.discoverServices();

      final service = services.firstWhere(
        (s) => s.serviceUuid == chessServiceUuid,
      );

      final characteristic = service.characteristics.firstWhere(
        (c) => c.characteristicUuid == chessCharacteristicUuid,
      );

      setState(() {
        _chessCharacteristic = characteristic;
      });

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            _connectedDevice = null;
            _chessCharacteristic = null;
          });
          _showSnackBar("Tabuleiro descontado.");
        }
      });
    } catch (e) {
      _showSnackBar("Falha na conexão: $e");
    }
  }

  Future<void> _sendTestMessage() async {
    if (_chessCharacteristic == null) {
      _showSnackBar("Nenhum dispositivo BLE pronto para receber dados.");
      return;
    }

    try {
      await _chessCharacteristic!.write(
        "PING".codeUnits,
        withoutResponse: false,
      );

      _showSnackBar("Mensagem PING enviada para o tabuleiro.");
    } catch (e) {
      _showSnackBar("Erro ao enviar mensagem: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuração do Tabuleiro (FBP)')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/images/logo.png"),
              Icon(
                _connectedDevice != null ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                size: 80,
                color: _connectedDevice != null ? Colors.blue : Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                _connectedDevice != null
                    ? 'Conectado a: ${_connectedDevice!.platformName}'
                    : 'Nenhum ESP32 conectado',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _isScanning ? null : _handleBleSetup,
                icon: _isScanning
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(_isScanning ? 'Buscando ESP32...' : 'Buscar Tabuleiro'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _sendTestMessage,
                icon: const Icon(Icons.send),
                label: const Text("Enviar teste BLE"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}