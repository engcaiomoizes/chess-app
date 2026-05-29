import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceController extends ChangeNotifier {
  static final VoiceController instance = VoiceController._();

  VoiceController._();

  final SpeechToText _speech = SpeechToText();

  bool isAvailable = false;
  bool isListening = false;

  String lastWords = "";
  String lastError = "";

  Future<void> initialize() async {
    isAvailable = await _speech.initialize(
      onStatus: (status) {
        isListening = status == "listening";
        notifyListeners();
      },
      onError: (error) {
        lastError = error.errorMsg;
        isListening = false;
        notifyListeners();
      },
    );

    notifyListeners();
  }

  Future<void> startListening({
    required void Function(String text) onResult,
  }) async {
    if (!isAvailable) {
      await initialize();
    }

    if (!isAvailable) {
      lastError = "Reconhecimento de voz não disponível.";
      notifyListeners();
      return;
    }

    lastWords = "";
    lastError = "";

    await _speech.listen(
      localeId: 'pt_BR',
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      onResult: (result) {
        lastWords = result.recognizedWords;
        notifyListeners();

        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    isListening = false;
    notifyListeners();
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
    isListening = false;
    notifyListeners();
  }
}