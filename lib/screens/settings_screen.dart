import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Setting keys ─────────────────────────────────────────────────────────────
class BxcSettings {
  static const String preferHighQuality   = 'pref_high_quality';
  static const String clarityBoost        = 'clarity_boost';
  static const String clarityBoostLevel   = 'clarity_boost_level';
  static const String skipSplash          = 'skip_splash';
  static const String disableSocial       = 'disable_social';
  static const String reduceAnimations    = 'reduce_animations';
  static const String showStreamStats     = 'show_stream_stats';
  static const String touchControllers    = 'touch_controllers';
  static const String videoBrightness     = 'video_brightness';
  static const String videoContrast       = 'video_contrast';
  static const String videoSaturation     = 'video_saturation';
  
  // New keys for v3
  static const String maxBitrate          = 'max_bitrate';
  static const String volumeBoost         = 'volume_boost';
  static const String aspectRatio         = 'aspect_ratio';
  static const String statsPosition       = 'stats_position';
  static const String showPlaytime        = 'show_playtime';
  static const String showBatteryHud      = 'show_battery_hud';
  static const String showDataUsage       = 'show_data_usage';
  static const String disableAnalytics    = 'disable_analytics';
  static const String simplifyMenu        = 'simplify_menu';
  static const String hideSystemMenuIcon  = 'hide_system_menu_icon';
  static const String fortniteConsole     = 'fortnite_console';
  static const String micAutoEnable       = 'mic_auto_enable';
  static const String hideHomeSections    = 'hide_home_sections';
  static const String preferIpv6          = 'prefer_ipv6';
  static const String serverRegion        = 'server_region';
  static const String gameLanguage        = 'game_language';
  static const String controllerStyle     = 'controller_style';
  static const String controllerOpacity   = 'controller_opacity';

  static Future<Map<String, dynamic>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      preferHighQuality:  prefs.getBool(preferHighQuality) ?? true,
      clarityBoost:       prefs.getBool(clarityBoost)      ?? false,
      clarityBoostLevel:  prefs.getDouble(clarityBoostLevel) ?? 1.0,
      skipSplash:         prefs.getBool(skipSplash)        ?? true,
      disableSocial:      prefs.getBool(disableSocial)     ?? false,
      reduceAnimations:   prefs.getBool(reduceAnimations)  ?? false,
      showStreamStats:    prefs.getBool(showStreamStats)   ?? false,
      touchControllers:   prefs.getBool(touchControllers)  ?? true,
      videoBrightness:    prefs.getDouble(videoBrightness) ?? 1.0,
      videoContrast:      prefs.getDouble(videoContrast)   ?? 1.0,
      videoSaturation:    prefs.getDouble(videoSaturation) ?? 1.0,
      
      maxBitrate:         prefs.getInt(maxBitrate)         ?? 0, // 0 = no limit
      volumeBoost:        prefs.getDouble(volumeBoost)      ?? 1.0,
      aspectRatio:        prefs.getString(aspectRatio)     ?? 'contain',
      statsPosition:      prefs.getString(statsPosition)   ?? 'top_right',
      showPlaytime:       prefs.getBool(showPlaytime)       ?? true,
      showBatteryHud:     prefs.getBool(showBatteryHud)     ?? true,
      showDataUsage:      prefs.getBool(showDataUsage)      ?? true,
      disableAnalytics:   prefs.getBool(disableAnalytics)   ?? true,
      simplifyMenu:       prefs.getBool(simplifyMenu)       ?? false,
      hideSystemMenuIcon: prefs.getBool(hideSystemMenuIcon) ?? false,
      fortniteConsole:    prefs.getBool(fortniteConsole)    ?? false,
      micAutoEnable:      prefs.getBool(micAutoEnable)      ?? false,
      hideHomeSections:   prefs.getBool(hideHomeSections)   ?? false,
      preferIpv6:         prefs.getBool(preferIpv6)         ?? false,
      serverRegion:       prefs.getString(serverRegion)    ?? 'auto',
      gameLanguage:       prefs.getString(gameLanguage)    ?? 'default',
      controllerStyle:    prefs.getString(controllerStyle)  ?? 'default',
      controllerOpacity:  prefs.getDouble(controllerOpacity) ?? 0.7,
    };
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SharedPreferences _prefs;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() => _loaded = true);
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _switchTile(String key, String title, String subtitle, {IconData? icon, bool def = false}) {
    return SwitchListTile.adaptive(
      secondary: icon != null ? Icon(icon, color: const Color(0xFF107C10)) : null,
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      value: _prefs.getBool(key) ?? def,
      activeColor: const Color(0xFF107C10),
      onChanged: (v) => setState(() => _prefs.setBool(key, v)),
    );
  }

  Widget _sliderTile(String key, String title, double min, double max, {int? divisions, String Function(double)? label, IconData? icon, double def = 1.0}) {
    final val = _prefs.getDouble(key) ?? def;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, color: const Color(0xFF107C10), size: 20), const SizedBox(width: 12)],
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
              const Spacer(),
              Text(label != null ? label(val) : val.toStringAsFixed(1), style: const TextStyle(color: Color(0xFF107C10), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Slider(
          value: val, min: min, max: max, divisions: divisions,
          activeColor: const Color(0xFF107C10),
          onChanged: (v) => setState(() => _prefs.setDouble(key, v)),
        ),
      ],
    );
  }

  Widget _dropdownTile<T>(String key, String title, List<DropdownMenuItem<T>> items, T def) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: DropdownButton<T>(
        value: (_prefs.get(key) as T?) ?? def,
        dropdownColor: const Color(0xFF1A1A1A),
        style: const TextStyle(color: Color(0xFF107C10), fontWeight: FontWeight.bold),
        items: items,
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            if (v is String) _prefs.setString(key, v);
            if (v is int) _prefs.setInt(key, v);
          });
        },
      ),
    );
  }

  // ── Tab Builders ───────────────────────────────────────────────────────────

  Widget _buildGeneralTab() {
    return ListView(
      children: [
        _switchTile(BxcSettings.fortniteConsole, 'Fortnite: Force Console', 'Play Save the World mode on iOS', icon: Icons.gamepad),
        _switchTile(BxcSettings.micAutoEnable, 'Auto-enable Microphone', 'Turn on mic automatically when game starts', icon: Icons.mic),
        _switchTile(BxcSettings.disableAnalytics, 'Disable Analytics', 'Block background telemetry sending', icon: Icons.privacy_tip, def: true),
      ],
    );
  }

  Widget _buildServerTab() {
    return ListView(
      children: [
        _switchTile(BxcSettings.preferIpv6, 'Prefer IPv6', 'May reduce latency if network supports it', icon: Icons.network_check),
        _dropdownTile(BxcSettings.serverRegion, 'Server Region', [
          const DropdownMenuItem(value: 'auto', child: Text('Auto')),
          const DropdownMenuItem(value: 'us_east', child: Text('US East')),
          const DropdownMenuItem(value: 'eu_west', child: Text('EU West')),
          const DropdownMenuItem(value: 'asia', child: Text('Asia')),
        ], 'auto'),
      ],
    );
  }

  Widget _buildStreamTab() {
    return ListView(
      children: [
        _switchTile(BxcSettings.preferHighQuality, '1080p / High Codec', 'Force best possible stream quality', icon: Icons.hd),
        _sliderTile(BxcSettings.maxBitrate.toString(), 'Max Bitrate (Mbps)', 0, 20, divisions: 20, label: (v) => v == 0 ? 'No Limit' : '${v.toInt()} Mbps', def: 0),
        _sliderTile(BxcSettings.volumeBoost, 'Volume Boost', 1.0, 6.0, divisions: 5, label: (v) => '${(v * 100).toInt()}%', icon: Icons.volume_up),
      ],
    );
  }

  Widget _buildHudTab() {
    return ListView(
      children: [
        _switchTile(BxcSettings.showStreamStats, 'Show Statistics', 'FPS, Ping, Loss, etc.'),
        _dropdownTile(BxcSettings.statsPosition, 'HUD Position', [
          const DropdownMenuItem(value: 'top_right', child: Text('Top Right')),
          const DropdownMenuItem(value: 'top_left', child: Text('Top Left')),
          const DropdownMenuItem(value: 'bottom_right', child: Text('Bottom Right')),
          const DropdownMenuItem(value: 'bottom_left', child: Text('Bottom Left')),
        ], 'top_right'),
        _switchTile(BxcSettings.showPlaytime, 'Show Playtime', 'Track session duration', def: true),
        _switchTile(BxcSettings.showBatteryHud, 'Show Battery', 'Device battery level in HUD', def: true),
      ],
    );
  }

  Widget _buildTouchTab() {
    return ListView(
      children: [
        _switchTile(BxcSettings.touchControllers, 'Virtual Controller', 'Enable on-screen gamepad'),
        _sliderTile(BxcSettings.controllerOpacity, 'Controller Opacity', 0.1, 1.0, icon: Icons.opacity, def: 0.7),
        _dropdownTile(BxcSettings.controllerStyle, 'Button Style', [
          const DropdownMenuItem(value: 'default', child: Text('Default')),
          const DropdownMenuItem(value: 'muted', child: Text('Muted')),
          const DropdownMenuItem(value: 'white', child: Text('All White')),
        ], 'default'),
      ],
    );
  }

  Widget _buildUiTab() {
    return ListView(
      children: [
        _switchTile(BxcSettings.skipSplash, 'Skip Splash Video', 'Save ~3 seconds on launch', def: true),
        _switchTile(BxcSettings.simplifyMenu, 'Simplify Stream Menu', 'Hide labels on menu buttons'),
        _switchTile(BxcSettings.hideSystemMenuIcon, 'Hide System Menu Icon', 'Dot icon at top won\'t block view'),
        _switchTile(BxcSettings.disableSocial, 'Disable Social Info', 'Hide friends/chat for faster load'),
        _switchTile(BxcSettings.reduceAnimations, 'Reduce Animations', 'Snap UI interactions'),
      ],
    );
  }

  Widget _buildVideoTab() {
    return ListView(
      children: [
        _switchTile(BxcSettings.clarityBoost, 'Clarity Boost', 'Sharpen stream visual'),
        if (_prefs.getBool(BxcSettings.clarityBoost) ?? false)
          _sliderTile(BxcSettings.clarityBoostLevel, 'Clarity Level', 0, 2, def: 1),
        _dropdownTile(BxcSettings.aspectRatio, 'Aspect Ratio', [
          const DropdownMenuItem(value: 'contain', child: Text('Original (16:9)')),
          const DropdownMenuItem(value: 'fill', child: Text('Stretch to Fill')),
          const DropdownMenuItem(value: 'cover', child: Text('Zoom to Fit')),
        ], 'contain'),
        _sectionHeader('Color Correction'),
        _sliderTile(BxcSettings.videoBrightness, 'Brightness', 0.5, 2.0),
        _sliderTile(BxcSettings.videoContrast, 'Contrast', 0.5, 2.0),
        _sliderTile(BxcSettings.videoSaturation, 'Saturation', 0.0, 2.0),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFF107C10), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Better xCloud Settings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF107C10),
          tabs: const [
            Tab(text: 'General'), Tab(text: 'Server'), Tab(text: 'Stream'),
            Tab(text: 'HUD'), Tab(text: 'Touch'), Tab(text: 'UI'), Tab(text: 'Video'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
      body: !_loaded ? const Center(child: CircularProgressIndicator()) : TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(), _buildServerTab(), _buildStreamTab(),
          _buildHudTab(), _buildTouchTab(), _buildUiTab(), _buildVideoTab(),
        ],
      ),
    );
  }
}
