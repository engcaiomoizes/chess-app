import 'package:chess_app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:chess_app/services/bluetooth/ble_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() {
    return HomePageState();
  }
}

class HomePageState extends State<HomePage> {
  final BleController ble = BleController.instance;

  Future<void> _onConnectPressed() async {
    if (ble.isConnected) {
      await ble.disconnect();
      _showSnackBar("Tabuleiro desconectado.");
      return;
    }

    try {
      await ble.startScan();

      if (!mounted) return;

      _showDeviceSelectionDialog();
    } catch (e) {
      _showSnackBar("Erro ao buscar dispositivos: $e");
    }
  }

  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AnimatedBuilder(
          animation: ble,
          builder: (context, _) {
            return AlertDialog(
              title: const Text("Selecione o tabuleiro"),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: ble.scanResults.isEmpty
                    ? const Center(
                        child: Text("Buscando dispositivos BLE..."),
                      )
                    : ListView.builder(
                        itemCount: ble.scanResults.length,
                        itemBuilder: (context, index) {
                          final result = ble.scanResults[index];
                          final device = result.device;
                          final name = ble.getDeviceName(result);

                          return ListTile(
                            leading: const Icon(
                              Icons.bluetooth,
                              color: Colors.deepPurple,
                            ),
                            title: Text(name),
                            subtitle: Text(
                              "ID: ${device.remoteId}\nRSSI: ${result.rssi} dBm",
                            ),
                            isThreeLine: true,
                            onTap: () async {
                              Navigator.of(context).pop();

                              try {
                                _showSnackBar("Conectando ao tabuleiro...");

                                await ble.connectToDevice(device);

                                if (!mounted) return;

                                _showSnackBar("Tabuleiro conectado com sucesso.");
                              } catch (e) {
                                _showSnackBar("Falha na conexão: $e");
                              }
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await ble.stopScan();

                    if (!context.mounted) return;

                    Navigator.of(context).pop();
                  },
                  child: const Text("Cancelar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendTestPing() async {
    try {
      await ble.sendPing();
      _showSnackBar("PING enviado.");
    } catch (e) {
      _showSnackBar("Erro ao enviar PING: $e");
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ble,
      builder: (context, _) {
        return Scaffold(
          body: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/logo.png"),
        
                ElevatedButton.icon(
                  label: Text(
                    ble.isConnected
                      ? "Desconectar"
                      : ble.isScanning
                        ? "Buscando..."
                        : "Conectar",
                  ),
                  icon: Icon(
                    ble.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth,
                  ),
                  onPressed: ble.isScanning ? null : _onConnectPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                  ),
                ),
        
                SizedBox(height: 10),
        
                ElevatedButton.icon(
                  label: const Text("Testar Bluetooth"),
                  icon: const Icon(Icons.send),
                  onPressed: ble.isConnected ? _sendTestPing : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                  ),
                ),
        
                SizedBox(height: 20),
        
                ElevatedButton.icon(
                  label: const Text("Iniciar Partida"),
                  icon: const Icon(Icons.gamepad_rounded),
                  onPressed: () {
                    Navigator.of(context).pushNamed("/game");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton.icon(
                  label: const Text("Histórico"),
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }
}

class CustomSwitcher extends StatelessWidget {
  const CustomSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Switch(
          value: AppController.instance.isDarkTheme,
          onChanged: (value) {
            AppController.instance.changeTheme();
          },
        );
  }
}