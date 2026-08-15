import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/local_storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.light;
  bool _isOffline = false;
  DateTime? _lastSyncTime;
  bool _hasPendingSyncs = false;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isOffline => _isOffline;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get hasPendingSyncs => _hasPendingSyncs;

  SettingsProvider() {
    _loadSettings();
    _listenToConnectivity();
  }

  /// Test-only seam: skips `_loadSettings()`/`_listenToConnectivity()`,
  /// which touch Hive boxes and a platform connectivity channel — neither
  /// available in a plain widget test without additional setup. Not used by
  /// any production code path.
  @visibleForTesting
  SettingsProvider.forTesting();

  /// Test-only seam: notifies listeners with no other side effects, for
  /// simulating an unrelated-provider rebuild in a widget test without
  /// touching LocalStorageService. Not used by any production code path.
  @visibleForTesting
  void debugNotifyForTesting() => notifyListeners();

  void _loadSettings() {
    final savedLocale = LocalStorageService.getLocale();
    if (savedLocale != null) {
      _locale = Locale(savedLocale);
    }

    final savedDarkMode = LocalStorageService.getDarkMode();
    _themeMode = savedDarkMode ? ThemeMode.dark : ThemeMode.light;

    _lastSyncTime = LocalStorageService.getLastSyncTime();
    _hasPendingSyncs = LocalStorageService.hasPendingSyncs();
  }

  void _listenToConnectivity() {
    SyncService.connectivityStream.listen((result) async {
      final wasOffline = _isOffline;
      _isOffline = result.isEmpty || result.contains(ConnectivityResult.none);
      
      // If we came back online and have pending syncs, trigger sync
      if (wasOffline && !_isOffline && _hasPendingSyncs) {
        await syncData();
      }
      
      notifyListeners();
    });
  }

  Future<void> setLocale(String languageCode) async {
    _locale = Locale(languageCode);
    await LocalStorageService.setLocale(languageCode);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await LocalStorageService.setDarkMode(_themeMode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    await LocalStorageService.setDarkMode(value);
    notifyListeners();
  }

  Future<void> syncData() async {
    if (_isOffline) return;
    
    await SyncService.syncData();
    _lastSyncTime = DateTime.now();
    _hasPendingSyncs = LocalStorageService.hasPendingSyncs();
    notifyListeners();
  }

  Future<void> fullSync() async {
    if (_isOffline) return;
    
    await SyncService.fullSync();
    _lastSyncTime = DateTime.now();
    _hasPendingSyncs = false;
    notifyListeners();
  }

  void updateSyncStatus() {
    _lastSyncTime = LocalStorageService.getLastSyncTime();
    _hasPendingSyncs = LocalStorageService.hasPendingSyncs();
    notifyListeners();
  }
}
