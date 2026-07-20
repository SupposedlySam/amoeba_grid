import 'package:liquid_grid/liquid_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists grid layouts with shared_preferences so shaping survives app
/// restarts. The package stays plugin-free; apps plug in storage like this.
class SharedPrefsGridStorage implements LiquidGridStorage {
  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
