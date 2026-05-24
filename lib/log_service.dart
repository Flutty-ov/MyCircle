import 'dart:async';

class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.type,
    required this.message,
  });

  final DateTime timestamp;
  final String type;
  final String message;

  @override
  String toString() {
    final time = timestamp.toLocal().toString().split('.').first;
    return '[$time] [$type] $message';
  }
}

class LogService {
  LogService._();

  static final LogService instance = LogService._();

  final List<LogEntry> _logs = [];
  final int _maxLogs = 500;

  final StreamController<LogEntry> _logStreamController =
      StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get logStream => _logStreamController.stream;

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void log(String type, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      type: type,
      message: message,
    );

    _logs.add(entry);

    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    _logStreamController.add(entry);
  }

  void info(String message) => log('INFO', message);
  void nav(String message) => log('NAV', message);
  void api(String message) => log('API', message);
  void tap(String message) => log('TAP', message);
  void error(String message) => log('ERROR', message);
  void chat(String message) => log('CHAT', message);
  void settings(String message) => log('SETTINGS', message);

  void clear() {
    _logs.clear();
  }

  String exportAll() {
    return _logs.map((e) => e.toString()).join('\n');
  }

  void dispose() {
    _logStreamController.close();
  }
}
