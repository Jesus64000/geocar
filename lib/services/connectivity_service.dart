import 'dart:async';
import 'dart:io';

class ConnectivityService {
  ConnectivityService._privateConstructor() {
    _startMonitoring();
  }

  static final ConnectivityService instance = ConnectivityService._privateConstructor();

  final _controller = StreamController<bool>.broadcast();
  bool _hasConnection = true;
  Timer? _timer;

  Stream<bool> get connectionStream => _controller.stream;
  bool get hasConnection => _hasConnection;

  void _startMonitoring() {
    // Verificación inicial
    _checkConnection();

    // Verificación periódica cada 5 segundos
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnection());
  }

  Future<void> _checkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      final connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (connected != _hasConnection) {
        _hasConnection = connected;
        _controller.add(_hasConnection);
      }
    } catch (_) {
      if (_hasConnection) {
        _hasConnection = false;
        _controller.add(false);
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
