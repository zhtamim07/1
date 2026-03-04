import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_screen.dart';

// ── Button index constants (matches virtual_gamepad.js BTN map) ───────────────
class GpBtn {
  static const int a = 0, b = 1, x = 2, y = 3;
  static const int lb = 4, rb = 5, lt = 6, rt = 7;
  static const int view = 8, menu = 9;
  static const int ls = 10, rs = 11;
  static const int dUp = 12, dDown = 13, dLeft = 14, dRight = 15;
  static const int guide = 16;
}

class GpAx {
  static const int lsX = 0, lsY = 1, rsX = 2, rsY = 3;
}

class VirtualGamepadBridge {
  final InAppWebViewController controller;
  VirtualGamepadBridge(this.controller);

  Future<void> pressButton(int index, bool pressed) => controller.evaluateJavascript(
        source: 'window.bxcGamepadButtonEvent($index, ${pressed ? 'true' : 'false'});',
      );

  Future<void> setAxis(int index, double value) => controller.evaluateJavascript(
        source: 'window.bxcGamepadAxisEvent($index, $value);',
      );

  Future<void> setTrigger(int buttonIndex, double value) =>
      controller.evaluateJavascript(
        source: 'window.bxcGamepadTriggerEvent($buttonIndex, $value);',
      );
}

class VirtualController extends StatefulWidget {
  final InAppWebViewController webController;
  final VoidCallback onClose;

  const VirtualController({
    super.key,
    required this.webController,
    required this.onClose,
  });

  @override
  State<VirtualController> createState() => _VirtualControllerState();
}

class _VirtualControllerState extends State<VirtualController> with WidgetsBindingObserver {
  late final VirtualGamepadBridge _bridge;
  Offset _lsOffset = Offset.zero;
  Offset _rsOffset = Offset.zero;
  final Set<int> _pressed = {};

  double _opacity = 0.7;
  String _style = 'default'; // 'default', 'muted', 'white'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bridge = VirtualGamepadBridge(widget.webController);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _resetAllInputs();
    }
  }

  void _resetAllInputs() {
    for (int btn in _pressed) {
      _bridge.pressButton(btn, false);
    }
    _bridge.setTrigger(GpBtn.lt, 0.0);
    _bridge.setTrigger(GpBtn.rt, 0.0);
    _bridge.setAxis(GpAx.lsX, 0.0);
    _bridge.setAxis(GpAx.lsY, 0.0);
    _bridge.setAxis(GpAx.rsX, 0.0);
    _bridge.setAxis(GpAx.rsY, 0.0);
    if (mounted) {
      setState(() {
        _pressed.clear();
        _lsOffset = Offset.zero;
        _rsOffset = Offset.zero;
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _opacity = prefs.getDouble(BxcSettings.controllerOpacity) ?? 0.7;
      _style = prefs.getString(BxcSettings.controllerStyle) ?? 'default';
    });
  }

  // ── Style Helpers ──────────────────────────────────────────────────────────

  Color _getButtonColor(Color base, {bool isPressed = false}) {
    if (_style == 'muted') return Colors.white.withOpacity(isPressed ? 0.4 : 0.1);
    if (_style == 'white') return Colors.white.withOpacity(isPressed ? 0.8 : 0.2);
    return isPressed ? base.withOpacity(0.9) : base.withOpacity(0.3);
  }

  Color _getLabelColor(Color base, {bool isPressed = false}) {
    if (_style == 'muted' || _style == 'white') return isPressed ? Colors.black : Colors.white;
    return isPressed ? Colors.white : base;
  }

  // ── Thumbstick ────────────────────────────────────────────────────────────

  Widget _buildThumbstick({
    required Offset offset,
    required int axisX,
    required int axisY,
    required ValueChanged<Offset> onUpdate,
    required VoidCallback onRelease,
    int? pressButton,
  }) {
    return Listener(
      onPointerDown: (e) => _updateStick(e.localPosition, axisX, axisY, onUpdate),
      onPointerMove: (e) => _updateStick(e.localPosition, axisX, axisY, onUpdate),
      onPointerUp: (_) {
        _bridge.setAxis(axisX, 0); _bridge.setAxis(axisY, 0);
        onRelease();
      },
      onPointerCancel: (_) {
        _bridge.setAxis(axisX, 0); _bridge.setAxis(axisY, 0);
        onRelease();
      },
      child: Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Center(
          child: Transform.translate(
            offset: offset,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(_style == 'white' ? 0.8 : 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateStick(Offset localPos, int axX, int axY, ValueChanged<Offset> onUpdate) {
    const radius = 40.0;
    final center = const Offset(50, 50);
    var delta = localPos - center;
    if (delta.distance > radius) delta = delta / delta.distance * radius;
    _bridge.setAxis(axX, (delta.dx / radius).clamp(-1, 1));
    _bridge.setAxis(axY, (delta.dy / radius).clamp(-1, 1));
    onUpdate(delta);
  }

  // ── Buttons ───────────────────────────────────────────────────────────────

  Widget _faceButton(int btn, String label, Color color) {
    final pressed = _pressed.contains(btn);
    return Listener(
      onPointerDown: (_) { setState(() => _pressed.add(btn)); _bridge.pressButton(btn, true); },
      onPointerUp: (_) { setState(() => _pressed.remove(btn)); _bridge.pressButton(btn, false); },
      onPointerCancel: (_) { setState(() => _pressed.remove(btn)); _bridge.pressButton(btn, false); },
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _getButtonColor(color, isPressed: pressed),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Center(child: Text(label, style: TextStyle(color: _getLabelColor(color, isPressed: pressed), fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _shoulderButton(int btn, String label, {bool isTrigger = false}) {
    final pressed = _pressed.contains(btn);
    return Listener(
      onPointerDown: (_) { 
        setState(() => _pressed.add(btn)); 
        isTrigger ? _bridge.setTrigger(btn, 1.0) : _bridge.pressButton(btn, true); 
      },
      onPointerUp: (_) { 
        setState(() => _pressed.remove(btn)); 
        isTrigger ? _bridge.setTrigger(btn, 0.0) : _bridge.pressButton(btn, false);
      },
      onPointerCancel: (_) { 
        setState(() => _pressed.remove(btn)); 
        isTrigger ? _bridge.setTrigger(btn, 0.0) : _bridge.pressButton(btn, false);
      },
      child: Container(
        width: 70, height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: _getButtonColor(const Color(0xFF107C10), isPressed: pressed),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
      ),
    );
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Opacity(
        opacity: _opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Column(children: [_shoulderButton(GpBtn.lt, 'LT', isTrigger: true), const SizedBox(height: 8), _shoulderButton(GpBtn.lb, 'LB')]),
                   Row(children: [
                     IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: widget.onClose),
                     _faceButton(GpBtn.guide, 'X', const Color(0xFF107C10)),
                   ]),
                   Column(children: [_shoulderButton(GpBtn.rt, 'RT', isTrigger: true), const SizedBox(height: 8), _shoulderButton(GpBtn.rb, 'RB')]),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildThumbstick(offset: _lsOffset, axisX: GpAx.lsX, axisY: GpAx.lsY, onUpdate: (o) => setState(() => _lsOffset = o), onRelease: () => setState(() => _lsOffset = Offset.zero)),
                  _buildThumbstick(offset: _rsOffset, axisX: GpAx.rsX, axisY: GpAx.rsY, onUpdate: (o) => setState(() => _rsOffset = o), onRelease: () => setState(() => _rsOffset = Offset.zero)),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(top: 0, child: _faceButton(GpBtn.y, 'Y', const Color(0xFFF7BD30))),
                      Positioned(bottom: 0, child: _faceButton(GpBtn.a, 'A', const Color(0xFF5DC21E))),
                      Positioned(left: 0, child: _faceButton(GpBtn.x, 'X', const Color(0xFF4AA6E0))),
                      Positioned(right: 0, child: _faceButton(GpBtn.b, 'B', const Color(0xFFEB4B4B))),
                      const SizedBox(width: 120, height: 120),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
