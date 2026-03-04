import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'settings_screen.dart';
import 'virtual_controller.dart';
import 'wallpaper_screen.dart';

// ── Stream stats model ────────────────────────────────────────────────────────
class StreamStats {
  final double fps;
  final int rttMs;
  final double mbps;
  final int packetsLost;
  final double jitter;
  final int playtime; // seconds

  const StreamStats({
    this.fps = 0,
    this.rttMs = 0,
    this.mbps = 0,
    this.packetsLost = 0,
    this.jitter = 0,
    this.playtime = 0,
  });

  factory StreamStats.fromJson(Map<String, dynamic> json) {
    final bytes = (json['bytes'] as num?)?.toDouble() ?? 0;
    return StreamStats(
      fps:         (json['fps']      as num?)?.toDouble() ?? 0,
      rttMs:       (json['rtt']      as num?)?.toInt()    ?? 0,
      mbps:        bytes / 1024 / 1024,
      packetsLost: (json['loss']     as num?)?.toInt()    ?? 0,
      jitter:      (json['jitter']   as num?)?.toDouble() ?? 0,
      playtime:    (json['playtime'] as num?)?.toInt()    ?? 0,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _hasError = false;
  bool _overlayVisible = false;
  bool _statsVisible   = false;
  bool _controllerVisible = false;
  
  StreamStats _stats = const StreamStats();
  Map<String, dynamic> _settings = {};
  
  final Battery _battery = Battery();
  int _batteryLevel = 100;

  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/17.0 Safari/605.1.15';
  static const String _xboxUrl = 'https://www.xbox.com/en-US/play';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _loadSettings();
    _listenBattery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
    } else if (state == AppLifecycleState.paused) {
      WakelockPlus.disable();
    }
  }

  void _listenBattery() {
    _battery.batteryLevel.then((l) => setState(() => _batteryLevel = l));
  }

  Future<void> _loadSettings() async {
    final s = await BxcSettings.loadAll();
    if (mounted) setState(() => _settings = s);
  }

  Future<String> _buildInjectionScript() async {
    final template = await rootBundle.loadString('assets/userscripts/additional.user.js');
    final bxFlags = jsonEncode({
      'DeviceInfo': {
        'deviceType': 'unknown',
        'androidInfo': {'webview': 'com.apple.webkit.wkwebview'},
      },
      'PreferHighQuality':      _settings[BxcSettings.preferHighQuality] ?? true,
      'MaxBitrate':             (_settings[BxcSettings.maxBitrate] as num?)?.toDouble() ?? 0,
      'VolumeBoost':            _settings[BxcSettings.volumeBoost] ?? 1.0,
      'AspectRatio':            _settings[BxcSettings.aspectRatio] ?? 'contain',
      'ClarityBoost': {
        'enabled': _settings[BxcSettings.clarityBoost] ?? false,
        'level':   _settings[BxcSettings.clarityBoostLevel] ?? 1.0,
      },
      'SkipSplashVideo':        _settings[BxcSettings.skipSplash] ?? true,
      'DisableSocialFeatures':  _settings[BxcSettings.disableSocial] ?? false,
      'SimplifyStreamMenu':     _settings[BxcSettings.simplifyMenu] ?? false,
      'HideSystemMenuIcon':     _settings[BxcSettings.hideSystemMenuIcon] ?? false,
      'ReduceAnimations':       _settings[BxcSettings.reduceAnimations] ?? false,
      'DisableAnalytics':       _settings[BxcSettings.disableAnalytics] ?? true,
      'FortniteConsole':        _settings[BxcSettings.fortniteConsole] ?? false,
      'MicAutoEnable':          _settings[BxcSettings.micAutoEnable] ?? false,
      'PreferIpv6':             _settings[BxcSettings.preferIpv6] ?? false,
      'VideoFilter': {
        'brightness': _settings[BxcSettings.videoBrightness] ?? 1.0,
        'contrast':   _settings[BxcSettings.videoContrast]   ?? 1.0,
        'saturation': _settings[BxcSettings.videoSaturation] ?? 1.0,
      },
    });
    return template.replaceAll('[[BX_FLAGS]]', bxFlags);
  }

  // ── HUD Overlay Widget ───────────────────────────────────────────────────

  Widget _buildStatsHud() {
    final pos = _settings[BxcSettings.statsPosition] ?? 'top_right';
    Alignment alignment = Alignment.topRight;
    if (pos == 'top_left') alignment = Alignment.topLeft;
    if (pos == 'bottom_right') alignment = Alignment.bottomRight;
    if (pos == 'bottom_left') alignment = Alignment.bottomLeft;

    return Align(
      alignment: alignment,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getStatColor(_stats.rttMs, 100, 200).withOpacity(0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_settings[BxcSettings.showPlaytime] ?? true)
                   _hudLine(Icons.timer_outlined, _formatDuration(_stats.playtime)),
                _hudLine(Icons.speed, '${_stats.fps.toInt()} FPS | ${_stats.rttMs}ms', color: _getStatColor(_stats.rttMs, 100, 200)),
                if (_settings[BxcSettings.showBatteryHud] ?? true)
                   _hudLine(Icons.battery_std, '$_batteryLevel%', color: _batteryLevel < 20 ? Colors.red : Colors.green),
                if (_settings[BxcSettings.showDataUsage] ?? true)
                   _hudLine(Icons.data_usage, '${_stats.mbps.toStringAsFixed(1)} MB'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hudLine(IconData icon, String text, {Color color = Colors.white}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: color.withOpacity(0.7)),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    ],
  );

  Color _getStatColor(num val, num good, num bad) {
    if (val < good) return Colors.green;
    if (val < bad) return Colors.yellow;
    return Colors.red;
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h > 0 ? '$h:' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── UI Handlers ─────────────────────────────────────────────────────────

  void _onLoadStop(InAppWebViewController c, WebUri? url) async {
    setState(() => _isLoading = false);
    if (url?.path.contains('/play') ?? false) {
      final script = await _buildInjectionScript();
      await c.evaluateJavascript(source: script);
      final gpScript = await rootBundle.loadString('assets/userscripts/virtual_gamepad.js');
      await c.evaluateJavascript(source: gpScript);
    }
  }

  Future<void> _takeScreenshot() async {
    final bytes = await _webViewController?.takeScreenshot();
    if (bytes != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Screenshot Taken')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_xboxUrl)),
            initialSettings: InAppWebViewSettings(
              userAgent: _userAgent,
              javaScriptEnabled: true,
              allowsInlineMediaPlayback: true,
              allowBackgroundAudioPlaying: true,
            ),
            onWebViewCreated: (c) {
              _webViewController = c;
              
              c.addJavaScriptHandler(handlerName: 'onStreamStats', callback: (args) {
                if (args.isNotEmpty) setState(() => _stats = StreamStats.fromJson(jsonDecode(args[0])));
              });

              // BxC Native Handlers Ported from Android
              c.addJavaScriptHandler(handlerName: 'vibrate', callback: (args) async {
                if (args.length >= 2) {
                  final String jsonStr = args[0];
                  final double intensity = (args[1] as num).toDouble();
                  if (intensity > 0) {
                     // In a full implementation, we'd parse the JSON for specific motors
                     // For iOS, trigger a heavy impact haptic when instructed
                     final int durationMs = (intensity * 100).toInt();
                     try {
                        await Vibration.vibrate(duration: durationMs.clamp(50, 500), amplitude: (intensity * 255).toInt().clamp(1, 255));
                     } catch(e) {
                        debugPrint("Vibration error: $e");
                     }
                  } else {
                     Vibration.cancel();
                  }
                }
              });

              c.addJavaScriptHandler(handlerName: 'saveScreenshot', callback: (args) async {
                 if (args.length >= 2) {
                    final String name = args[0];
                    final String data = args[1]; // Base64 data from Web
                    try {
                      final parts = data.split(',');
                      final bytes = base64Decode(parts.length > 1 ? parts[1] : parts[0]);
                      final result = await ImageGallerySaver.saveImage(bytes, name: name);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['isSuccess'] ? 'Screenshot saved to Photos' : 'Failed to save screenshot')));
                      }
                      Vibration.vibrate(duration: 100);
                    } catch(e) {
                      debugPrint('Screenshot save error: $e');
                    }
                 }
              });

              c.addJavaScriptHandler(handlerName: 'runShortcut', callback: (args) async {
                 if (args.isNotEmpty) {
                    final String action = args[0];
                    switch(action) {
                      case 'device.brightness.dec':
                        final cur = await ScreenBrightness().current;
                        await ScreenBrightness().setScreenBrightness((cur - 0.1).clamp(0.0, 1.0));
                        break;
                      case 'device.brightness.inc':
                        final cur = await ScreenBrightness().current;
                        await ScreenBrightness().setScreenBrightness((cur + 0.1).clamp(0.0, 1.0));
                        break;
                      case 'device.volume.dec':
                        final cur = await VolumeController().getVolume();
                        VolumeController().setVolume((cur - 0.1).clamp(0.0, 1.0));
                        break;
                      case 'device.volume.inc':
                        final cur = await VolumeController().getVolume();
                        VolumeController().setVolume((cur + 0.1).clamp(0.0, 1.0));
                        break;
                    }
                 }
              });

              c.addJavaScriptHandler(handlerName: 'downloadWallpapers', callback: (args) {
                 if (args.length >= 2) {
                   final titleSlug = args[0];
                   final productId = args[1];
                   if (mounted) {
                      Navigator.push(context, MaterialPageRoute(
                         builder: (_) => WallpaperScreen(
                            titleSlug: titleSlug,
                            productId: productId,
                         )
                      ));
                   }
                   Vibration.vibrate(duration: 50);
                 }
              });
              
            },
            onLoadStop: _onLoadStop,
            onProgressChanged: (c, p) => setState(() => _loadingProgress = p / 100.0),
          ),

          // HUD
          if (_statsVisible) _buildStatsHud(),

          // Overlay Control Hint
          if (!_overlayVisible)
            Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.more_vert, color: Colors.white24), 
            onPressed: () => setState(() => _overlayVisible = true))),

          // Overlay Controls
          if (_overlayVisible) 
            GestureDetector(
              onTap: () => setState(() => _overlayVisible = false),
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _overlayBtn(Icons.settings, () async {
                        final reload = await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        if (reload == true) _webViewController?.reload();
                        _loadSettings();
                      }),
                      _overlayBtn(Icons.gamepad, () => setState(() => _controllerVisible = !_controllerVisible)),
                      _overlayBtn(Icons.bar_chart, () => setState(() => _statsVisible = !_statsVisible)),
                      _overlayBtn(Icons.camera_alt, _takeScreenshot),
                      _overlayBtn(Icons.close, () => setState(() => _overlayVisible = false)),
                    ],
                  ),
                ),
              ),
            ),

          if (_controllerVisible && _webViewController != null)
            VirtualController(webController: _webViewController!, onClose: () => setState(() => _controllerVisible = false)),

          if (_isLoading) LinearProgressIndicator(value: _loadingProgress, color: const Color(0xFF107C10), backgroundColor: Colors.transparent),
        ],
      ),
    );
  }

  Widget _overlayBtn(IconData icon, VoidCallback onTap) => IconButton(
    icon: Icon(icon, color: Colors.white, size: 32),
    onPressed: onTap,
  );
}
