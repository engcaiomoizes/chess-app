import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';

class BleController extends ChangeNotifier {
  static final BleController instance = BleController._();

  BleController._();

  final Guid chessServiceUuid = Guid("A07498CA-AD5B-474E-940D-16F1FBE7E8CD");
  final Guid chessCharacteristicUuid = Guid("51FF12BB-3ED8-46E5-B4F9-D64E2FEC021B");

  List<ScanResult> scanResults = [];

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? chessCharacteristic;

  bool isScanning = false;

  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  bool get isConnected {
    return connectedDevice != null && chessCharacteristic != null;
  }

  Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<bool> hasPermissions() async {
    if (!Platform.isAndroid) return true;

    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;

    return scan.isGranted && connect.isGranted;
  }

  Future<void> startScan() async {
    final isSupported = await FlutterBluePlus.isSupported;

    if (!isSupported) {
      throw Exception("Permissões de Bluetooth negadas.");
    }

    await requestPermissions();

    final permitted = await hasPermissions();

    if (!permitted) {
      throw Exception("Permissões de Bluetooth negadas.");
    }

    final adapterState = await FlutterBluePlus.adapterState.first;

    if (adapterState != BluetoothAdapterState.on) {
      throw Exception("O Bluetooth está desligado.");
    }

    await FlutterBluePlus.stopScan();
    
    scanResults.clear();
    notifyListeners();

    await _scanResultsSubscription?.cancel();

    _scanResultsSubscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        for (final result in results) {
          final index = scanResults.indexWhere(
            (item) => item.device.remoteId == result.device.remoteId,
          );

          if (index >= 0) {
            scanResults[index] = result;
          } else {
            scanResults.add(result);
          }
        }

        debugPrint("Dispositivos encontrados: ${scanResults.length}");

        for (final result in scanResults) {
          debugPrint(
            "BLE: "
            "name=${getDeviceName(result)} | "
            "id=${result.device.remoteId} | "
            "rssi=${result.rssi} | "
            "services=${result.advertisementData.serviceUuids}",
          );
        }

        notifyListeners();
      },
      onError: (e) {
        debugPrint("Erro no scan BLE: $e");
      },
    );

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      androidUsesFineLocation: false,
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();

    await Future.delayed(const Duration(milliseconds: 500));

    await device.connect(
      license: License.free,
      timeout: const Duration(seconds: 25),
      autoConnect: false,
    );

    final services = await device.discoverServices();

    final hasChessService = services.any(
      (service) => service.serviceUuid == chessServiceUuid,
    );

    if (!hasChessService) {
      await device.disconnect();
      throw Exception("Este dispositivo não possui o serviço do tabuleiro.");
    }

    final service = services.firstWhere(
      (service) => service.serviceUuid == chessServiceUuid,
    );

    final characteristic = service.characteristics.firstWhere(
      (c) => c.characteristicUuid == chessCharacteristicUuid,
    );

    connectedDevice = device;
    chessCharacteristic = characteristic;

    await _connectionSubscription?.cancel();

    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        connectedDevice = null;
        chessCharacteristic = null;
        notifyListeners();
      }
    });

    notifyListeners();
  }

  Future<void> disconnect() async {
    await connectedDevice?.disconnect();

    connectedDevice = null;
    chessCharacteristic = null;

    notifyListeners();
  }

  Future<void> sendText(String text) async {
    if (chessCharacteristic == null) {
      debugPrint("Nenhum dispositivo BLE conectado.");
      return;
    }

    await chessCharacteristic!.write(
      text.codeUnits,
      withoutResponse: false,
    );
  }

  Future<void> sendChessMove(String moveUci) async {
    await sendText(moveUci);
  }

  Future<void> sendPing() async {
    await sendText("PING");
  }

  String getDeviceName(ScanResult result) {
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }

    if (result.advertisementData.localName.isNotEmpty) {
      return result.advertisementData.localName;
    }

    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }

    return "N/A - possível tabuleiro BLE";
  }
}