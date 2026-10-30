import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Lê textos em português em voz alta e informa qual trecho está sendo falado,
/// para a tela destacar a palavra atual. Só um texto toca por vez.
class PortugueseReader extends ChangeNotifier {
  PortugueseReader() {
    _tts.setProgressHandler((text, start, end, word) {
      if (_disposed || _playingId == null) return;
      _wordStart = start;
      _wordEnd = end;
      notifyListeners();
    });
    _tts.setCompletionHandler(_onFinished);
    _tts.setCancelHandler(_onFinished);
    _tts.setErrorHandler((_) => _onFinished());
  }

  final FlutterTts _tts = FlutterTts();
  bool _configured = false;
  bool _disposed = false;

  String? _playingId;

  // Ao trocar de texto, o fim/cancelamento da leitura anterior chega atrasado
  // (na web vem como erro "interrupted") e não pode apagar a leitura nova.
  DateTime _ignoreFinishUntil = DateTime.fromMillisecondsSinceEpoch(0);
  int _wordStart = 0;
  int _wordEnd = 0;

  String? get playingId => _playingId;
  int get wordStart => _wordStart;
  int get wordEnd => _wordEnd;

  bool isPlaying(String id) => _playingId == id;

  /// Retorna false quando o aparelho não tem voz em português.
  Future<bool> play(String id, String text) async {
    await stop();
    if (!_configured) {
      final available = kIsWeb || await _tts.isLanguageAvailable('pt-BR') == true;
      if (!available) return false;
      await _tts.setLanguage('pt-BR');
      // A escala de velocidade é diferente na web (1.0 = normal) e no Android (0.5 = normal).
      await _tts.setSpeechRate(kIsWeb ? 0.85 : 0.42);
      _configured = true;
    }
    _playingId = id;
    _wordStart = 0;
    _wordEnd = 0;
    notifyListeners();
    await _tts.speak(text);
    return true;
  }

  Future<void> stop() async {
    if (_playingId == null) return;
    _ignoreFinishUntil = DateTime.now().add(const Duration(milliseconds: 600));
    await _tts.stop();
    _reset();
  }

  void _onFinished() {
    if (DateTime.now().isBefore(_ignoreFinishUntil)) return;
    _reset();
  }

  void _reset() {
    if (_disposed || _playingId == null) return;
    _playingId = null;
    _wordStart = 0;
    _wordEnd = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tts.stop();
    super.dispose();
  }
}
