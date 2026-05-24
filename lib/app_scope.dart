import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:cryptography/cryptography.dart';
import 'package:ras/cache_service.dart';
import 'log_service.dart';

class _AppPrefsKeys {
  static const onboardingCompleted = 'onboardingCompleted';
  static const devNoticeShown = 'devNoticeShown';
  static const displayName = 'displayName';
  static const themeMode = 'themeMode';
  static const notesMessages = 'notesMessages';
  static const birthday = 'birthday';
  static const seedColor = 'seedColor';
  static const chatWallpaper = 'chatWallpaper';
  static const notificationsEnabled = 'notificationsEnabled';
  static const characterToken = 'characterToken';
  static const chatTokensByChatId = 'chatTokensByChatId';
  static const addedChats = 'addedChats';
  static const advancedComposerEnabled = 'advancedComposerEnabled';
  static const messengerNavEnabled = 'messengerNavEnabled';
  static const messengerNavLensFlipY = 'messengerNavLensFlipY';
  static const iosInputPanelEnabled = 'iosInputPanelEnabled';
  static const telegramStyleEnabled = 'telegramStyleEnabled';
  static const myCircleChannelSubscribed = 'myCircleChannelSubscribed';
  static const appLanguage = 'appLanguage';
  static const passcodeSalt = 'passcodeSalt';
  static const passcodeHash = 'passcodeHash';
  static const passcodeLocked = 'passcodeLocked';
  static const passcodeAutoLockSeconds = 'passcodeAutoLockSeconds';
  static const autoCleanupTypes = 'autoCleanupTypes';
  static const autoCleanupDays = 'autoCleanupDays';
  static const lastAutoCleanupDate = 'lastAutoCleanupDate';
  static const chatNameOverrides = 'chatNameOverrides';
  static const chatIconOverrides = 'chatIconOverrides';
}

class AppController extends ChangeNotifier {
  AppController(this._prefs);

  final SharedPreferences _prefs;
  bool _characterSyncStarted = false;

  String get supabaseUrl =>
      (_prefs.getString('server.supabase.url') ?? '').trim();

  String get supabaseAnonKey =>
      (_prefs.getString('server.supabase.anonKey') ?? '').trim();

  bool get onboardingCompleted =>
      _prefs.getBool(_AppPrefsKeys.onboardingCompleted) ?? false;

  bool get devNoticeShown =>
      _prefs.getBool(_AppPrefsKeys.devNoticeShown) ?? false;

  Future<void> setDevNoticeShown(bool value) async {
    await _prefs.setBool(_AppPrefsKeys.devNoticeShown, value);
    notifyListeners();
  }

  String? get displayName => _prefs.getString(_AppPrefsKeys.displayName);

  bool get notificationsEnabled =>
      _prefs.getBool(_AppPrefsKeys.notificationsEnabled) ?? false;

  bool get advancedComposerEnabled =>
      _prefs.getBool(_AppPrefsKeys.advancedComposerEnabled) ?? false;

  Future<void> setAdvancedComposerEnabled(bool value) async {
    if (value) {
      await _prefs.setBool(_AppPrefsKeys.iosInputPanelEnabled, false);
    }
    await _prefs.setBool(_AppPrefsKeys.advancedComposerEnabled, value);
    notifyListeners();
  }

  bool get iosInputPanelEnabled =>
      _prefs.getBool(_AppPrefsKeys.iosInputPanelEnabled) ?? false;

  Future<void> setIosInputPanelEnabled(bool value) async {
    if (value) {
      await _prefs.setBool(_AppPrefsKeys.advancedComposerEnabled, false);
    }
    await _prefs.setBool(_AppPrefsKeys.iosInputPanelEnabled, value);
    notifyListeners();
  }

  bool get telegramStyleEnabled =>
      _prefs.getBool(_AppPrefsKeys.telegramStyleEnabled) ?? false;

  Future<void> setTelegramStyleEnabled(bool value) async {
    await _prefs.setBool(_AppPrefsKeys.telegramStyleEnabled, value);
    notifyListeners();
  }

  bool get myCircleChannelSubscribed =>
      _prefs.getBool(_AppPrefsKeys.myCircleChannelSubscribed) ?? false;

  Future<void> setMyCircleChannelSubscribed(bool value) async {
    await _prefs.setBool(_AppPrefsKeys.myCircleChannelSubscribed, value);
    notifyListeners();
  }

  String get appLanguage =>
      (_prefs.getString(_AppPrefsKeys.appLanguage) ?? 'ru');

  Future<void> setAppLanguage(String code) async {
    await _prefs.setString(_AppPrefsKeys.appLanguage, code);
    notifyListeners();
  }

  bool get hasPasscode {
    final h = (_prefs.getString(_AppPrefsKeys.passcodeHash) ?? '').trim();
    final s = (_prefs.getString(_AppPrefsKeys.passcodeSalt) ?? '').trim();
    return h.isNotEmpty && s.isNotEmpty;
  }

  bool get passcodeLocked {
    if (!hasPasscode) return false;
    return _prefs.getBool(_AppPrefsKeys.passcodeLocked) ?? true;
  }

  Future<void> setPasscodeLocked(bool value) async {
    if (!hasPasscode) return;
    await _prefs.setBool(_AppPrefsKeys.passcodeLocked, value);
    notifyListeners();
  }

  int get passcodeAutoLockSeconds {
    final v = _prefs.getInt(_AppPrefsKeys.passcodeAutoLockSeconds);
    return v ?? 0;
  }

  Future<void> setPasscodeAutoLockSeconds(int seconds) async {
    await _prefs.setInt(_AppPrefsKeys.passcodeAutoLockSeconds, seconds);
    notifyListeners();
  }

  bool _inChatPage = false;
  bool get inChatPage => _inChatPage;

  void setInChatPage(bool value) {
    if (_inChatPage == value) return;
    _inChatPage = value;
  }

  Set<String> get autoCleanupTypes {
    final types =
        _prefs.getStringList(_AppPrefsKeys.autoCleanupTypes) ?? const [];
    return types.toSet();
  }

  Future<void> setAutoCleanupTypes(Set<String> types) async {
    await _prefs.setStringList(_AppPrefsKeys.autoCleanupTypes, types.toList());
    notifyListeners();
  }

  int get autoCleanupDays {
    return _prefs.getInt(_AppPrefsKeys.autoCleanupDays) ?? 0;
  }

  Future<void> setAutoCleanupDays(int days) async {
    await _prefs.setInt(_AppPrefsKeys.autoCleanupDays, days);
    notifyListeners();
  }

  DateTime? get lastAutoCleanupDate {
    final timestamp = _prefs.getInt(_AppPrefsKeys.lastAutoCleanupDate);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> setLastAutoCleanupDate(DateTime date) async {
    await _prefs.setInt(
      _AppPrefsKeys.lastAutoCleanupDate,
      date.millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  Future<void> checkAndPerformAutoCleanup() async {
    final days = autoCleanupDays;
    final types = autoCleanupTypes;

    if (days <= 0 || types.isEmpty) return;

    final lastCleanup = lastAutoCleanupDate;
    final now = DateTime.now();

    if (lastCleanup != null) {
      final daysSinceLastCleanup = now.difference(lastCleanup).inDays;
      if (daysSinceLastCleanup < days) return;
    }

    await _performAutoCleanup(types);
    await setLastAutoCleanupDate(now);
  }

  Future<void> _performAutoCleanup(Set<String> types) async {
    for (final type in types) {
      CacheCategory? category;
      switch (type) {
        case 'video':
          category = CacheCategory.video;
          break;
        case 'photo':
          category = CacheCategory.photo;
          break;
        case 'files':
          category = CacheCategory.file;
          break;
        case 'stickers':
          category = CacheCategory.sticker;
          break;
        case 'other':
          category = CacheCategory.other;
          break;
      }
      if (category != null) {
        await CacheService.instance.clearCacheByCategory(category);
      }
    }
  }

  Future<void> clearPasscode() async {
    await _prefs.remove(_AppPrefsKeys.passcodeHash);
    await _prefs.remove(_AppPrefsKeys.passcodeSalt);
    await _prefs.remove(_AppPrefsKeys.passcodeLocked);
    notifyListeners();
  }

  Future<void> setPasscode(String code) async {
    final normalized = code.trim();
    if (normalized.length != 6) return;
    final salt = const Uuid().v4();
    final hash = await _hashPasscode(code: normalized, salt: salt);
    await _prefs.setString(_AppPrefsKeys.passcodeSalt, salt);
    await _prefs.setString(_AppPrefsKeys.passcodeHash, hash);
    await _prefs.setBool(_AppPrefsKeys.passcodeLocked, true);
    notifyListeners();
  }

  Future<bool> verifyPasscode(String code) async {
    if (!hasPasscode) return true;
    final salt = (_prefs.getString(_AppPrefsKeys.passcodeSalt) ?? '').trim();
    final existing = (_prefs.getString(_AppPrefsKeys.passcodeHash) ?? '')
        .trim();
    if (salt.isEmpty || existing.isEmpty) return false;
    final next = await _hashPasscode(code: code.trim(), salt: salt);
    return next == existing;
  }

  Future<String> _hashPasscode({
    required String code,
    required String salt,
  }) async {
    final algo = Sha256();
    final bytes = <int>[...code.codeUnits, 0, ...salt.codeUnits];
    final digest = await algo.hash(bytes);
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  bool get messengerNavEnabled =>
      _prefs.getBool(_AppPrefsKeys.messengerNavEnabled) ?? false;

  Future<void> setMessengerNavEnabled(bool value) async {
    await _prefs.setBool(_AppPrefsKeys.messengerNavEnabled, value);
    notifyListeners();
  }

  bool get messengerNavLensFlipY =>
      _prefs.getBool(_AppPrefsKeys.messengerNavLensFlipY) ?? true;

  Future<void> setMessengerNavLensFlipY(bool value) async {
    await _prefs.setBool(_AppPrefsKeys.messengerNavLensFlipY, value);
    notifyListeners();
  }

  String get characterToken {
    final existing = _prefs.getString(_AppPrefsKeys.characterToken);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    _prefs.setString(_AppPrefsKeys.characterToken, created);
    return created;
  }

  Map<String, String> get _chatTokensByChatId {
    final raw = _prefs.getString(_AppPrefsKeys.chatTokensByChatId);
    if (raw == null || raw.isEmpty) return <String, String>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, String>{};
    return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  String? getChatToken({required String chatUuid, String? legacyChatId}) {
    final map = _chatTokensByChatId;
    final byUuid = map[chatUuid];
    if (byUuid != null && byUuid.isNotEmpty) return byUuid;

    final legacy = legacyChatId == null ? null : map[legacyChatId];
    if (legacy != null && legacy.isNotEmpty) {
      final updated = Map<String, String>.from(map);
      updated[chatUuid] = legacy;
      updated.remove(legacyChatId);
      _prefs.setString(_AppPrefsKeys.chatTokensByChatId, jsonEncode(updated));
      notifyListeners();
      return legacy;
    }

    return null;
  }

  Future<void> setChatToken({
    required String chatUuid,
    required String token,
  }) async {
    final updated = _chatTokensByChatId;
    updated[chatUuid] = token;
    await _prefs.setString(
      _AppPrefsKeys.chatTokensByChatId,
      jsonEncode(updated),
    );
    notifyListeners();
  }

  List<Map<String, String>> get addedChats {
    final raw = _prefs.getString(_AppPrefsKeys.addedChats);
    if (raw == null || raw.isEmpty) return const <Map<String, String>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Map<String, String>>[];

      final out = <Map<String, String>>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        final chatUuid = (e['chatUuid'] ?? '').toString();
        if (chatUuid.isEmpty) continue;
        out.add({
          'chatUuid': chatUuid,
          'chatId': (e['chatId'] ?? '').toString(),
          'chatName': (e['chatName'] ?? '').toString(),
        });
      }
      return out;
    } catch (_) {
      return const <Map<String, String>>[];
    }
  }

  Future<void> addChat({
    required String chatUuid,
    required String chatId,
    required String chatName,
  }) async {
    final existing = addedChats;
    final idx = existing.indexWhere((e) => e['chatUuid'] == chatUuid);
    final updated = <Map<String, String>>[...existing];
    final item = {'chatUuid': chatUuid, 'chatId': chatId, 'chatName': chatName};
    if (idx >= 0) {
      updated[idx] = item;
    } else {
      updated.add(item);
    }
    await _prefs.setString(_AppPrefsKeys.addedChats, jsonEncode(updated));
    notifyListeners();
  }

  Future<void> removeChats(Set<String> chatUuids) async {
    if (chatUuids.isEmpty) return;
    final existing = addedChats;
    final updated = existing
        .where((e) => !chatUuids.contains((e['chatUuid'] ?? '').toString()))
        .toList(growable: false);
    await _prefs.setString(_AppPrefsKeys.addedChats, jsonEncode(updated));
    notifyListeners();
  }

  Map<String, String> get _chatNameOverrides {
    final raw = _prefs.getString(_AppPrefsKeys.chatNameOverrides);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  String getChatDisplayName({required String chatUuid, required String fallback}) {
    final overrides = _chatNameOverrides;
    final custom = overrides[chatUuid];
    if (custom != null && custom.isNotEmpty) return custom;
    return fallback;
  }

  Future<void> setChatDisplayName({
    required String chatUuid,
    required String name,
  }) async {
    final updated = Map<String, String>.from(_chatNameOverrides);
    if (name.trim().isEmpty) {
      updated.remove(chatUuid);
    } else {
      updated[chatUuid] = name.trim();
    }
    await _prefs.setString(_AppPrefsKeys.chatNameOverrides, jsonEncode(updated));
    notifyListeners();
  }

  Map<String, String> get _chatIconOverrides {
    final raw = _prefs.getString(_AppPrefsKeys.chatIconOverrides);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  String? getChatIcon({required String chatUuid}) {
    final overrides = _chatIconOverrides;
    final icon = overrides[chatUuid];
    if (icon != null && icon.isNotEmpty) return icon;
    return null;
  }

  Future<void> setChatIcon({
    required String chatUuid,
    required String? iconPath,
  }) async {
    final updated = Map<String, String>.from(_chatIconOverrides);
    if (iconPath == null || iconPath.trim().isEmpty) {
      updated.remove(chatUuid);
    } else {
      updated[chatUuid] = iconPath.trim();
    }
    await _prefs.setString(_AppPrefsKeys.chatIconOverrides, jsonEncode(updated));
    notifyListeners();
  }

  void ensureCharacterSynced() {
    if (_characterSyncStarted) return;
    _characterSyncStarted = true;
    Future<void>(() async {
      try {
        final name = displayName ?? '';
        await Supabase.instance.client.from('characters').upsert({
          'token': characterToken,
          'name': name,
        });
      } catch (_) {
        // Ignore network/db errors; UI should keep working offline.
      }
    });
  }

  DateTime? get birthday {
    final raw = _prefs.getString(_AppPrefsKeys.birthday);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Color get seedColor {
    final value = _prefs.getInt(_AppPrefsKeys.seedColor);
    if (value == null) return Colors.blue;
    return Color(value);
  }

  String? get chatWallpaper => _prefs.getString(_AppPrefsKeys.chatWallpaper);

  ThemeMode get themeMode {
    final mode = _prefs.getString(_AppPrefsKeys.themeMode);
    if (mode == 'dark') return ThemeMode.dark;
    if (mode == 'light') return ThemeMode.light;
    return ThemeMode.light;
  }

  Future<void> setDisplayName(String value) async {
    LogService.instance.info('Смена имени: "$value"');
    await _prefs.setString(_AppPrefsKeys.displayName, value);
    notifyListeners();

    try {
      await Supabase.instance.client.from('characters').upsert({
        'token': characterToken,
        'name': value,
      });
      LogService.instance.api('Supabase: обновление имени в characters');
    } catch (e) {
      LogService.instance.error('Supabase: ошибка обновления имени: $e');
    }
  }

  Future<void> setBirthday(DateTime? value) async {
    if (value == null) {
      await _prefs.remove(_AppPrefsKeys.birthday);
    } else {
      await _prefs.setString(_AppPrefsKeys.birthday, value.toIso8601String());
    }
    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    await _prefs.setInt(_AppPrefsKeys.seedColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setChatWallpaper(String? assetPath) async {
    if (assetPath == null || assetPath.isEmpty) {
      await _prefs.remove(_AppPrefsKeys.chatWallpaper);
    } else {
      await _prefs.setString(_AppPrefsKeys.chatWallpaper, assetPath);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(
      _AppPrefsKeys.themeMode,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs.setBool(_AppPrefsKeys.notificationsEnabled, value);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_AppPrefsKeys.onboardingCompleted, true);
    notifyListeners();
  }

  Future<void> resetAllData() async {
    await _prefs.clear();
    notifyListeners();
  }

  List<String> get notesMessages =>
      _prefs.getStringList(_AppPrefsKeys.notesMessages) ?? const [];

  Future<void> addNotesMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    final updated = [...notesMessages, trimmed];
    await _prefs.setStringList(_AppPrefsKeys.notesMessages, updated);
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    required AppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw StateError('AppScope not found in widget tree');
    }
    final controller = scope.notifier;
    if (controller == null) {
      throw StateError('AppController not found in AppScope');
    }
    return controller;
  }
}
