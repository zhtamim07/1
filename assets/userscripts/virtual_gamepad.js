/* =============================================================
 * Better xCloud iOS — Virtual Gamepad Injector
 * Injected separately after page load alongside additional.user.js
 * Creates a fake Gamepad API that Xbox Cloud Gaming reads as a real
 * connected controller.
 * ============================================================= */

(function () {
    'use strict';

    if (!window.location.pathname.includes('/play')) return;
    if (window.__bxcVirtualGamepadInstalled) return;
    window.__bxcVirtualGamepadInstalled = true;

    // ── Virtual gamepad state ────────────────────────────────────────────────
    // Standard mapping: 17 buttons, 4 axes
    // Buttons: [A, B, X, Y, LB, RB, LT, RT, Select/View, Start/Menu, LS, RS,
    //           DPad-Up, DPad-Down, DPad-Left, DPad-Right, Guide/Home]
    const _buttonCount = 17;
    const _axisCount = 4;

    const _state = {
        connected: true,
        id: 'Xbox 360 Controller (XInput STANDARD GAMEPAD)',
        index: 0,
        mapping: 'standard',
        timestamp: performance.now(),
        axes: new Float32Array(_axisCount),   // [LS-X, LS-Y, RS-X, RS-Y]
        buttons: Array.from({ length: _buttonCount }, () => ({
            pressed: false,
            touched: false,
            value: 0,
        })),
        hapticActuators: [],
        vibrationActuator: {
            type: 'dual-rumble',
            playEffect: () => Promise.resolve('complete'),
            reset: () => Promise.resolve('complete'),
        },
    };

    // ── Button index map ─────────────────────────────────────────────────────
    const BTN = {
        A: 0, B: 1, X: 2, Y: 3,
        LB: 4, RB: 5, LT: 6, RT: 7,
        VIEW: 8, MENU: 9,
        LS: 10, RS: 11,
        DPAD_UP: 12, DPAD_DOWN: 13, DPAD_LEFT: 14, DPAD_RIGHT: 15,
        GUIDE: 16,
    };
    window.BXC_BTN = BTN;   // expose so Flutter bridge can reference by name

    // ── Axis index map ───────────────────────────────────────────────────────
    const AX = { LS_X: 0, LS_Y: 1, RS_X: 2, RS_Y: 3 };
    window.BXC_AX = AX;

    // ── Flutter → JS API ─────────────────────────────────────────────────────
    /**
     * Called from Flutter via evaluateJavascript when a button is pressed.
     * buttonIndex: 0-16 (standard mapping)
     * pressed: true/false
     */
    window.bxcGamepadButtonEvent = function (buttonIndex, pressed) {
        if (buttonIndex < 0 || buttonIndex >= _buttonCount) return;
        const val = pressed ? 1.0 : 0.0;
        _state.buttons[buttonIndex] = { pressed, touched: pressed, value: val };
        _state.timestamp = performance.now();
    };

    /**
     * Called from Flutter for analog triggers (LT/RT) and thumbsticks.
     * axisIndex: 0-3  OR  buttonIndex: 6 (LT) / 7 (RT)
     * value: -1.0 to 1.0 for axes, 0.0 to 1.0 for triggers
     */
    window.bxcGamepadAxisEvent = function (index, value) {
        if (index >= 0 && index < _axisCount) {
            _state.axes[index] = Math.max(-1, Math.min(1, value));
            _state.timestamp = performance.now();
        }
    };

    window.bxcGamepadTriggerEvent = function (buttonIndex, value) {
        const v = Math.max(0, Math.min(1, value));
        _state.buttons[buttonIndex] = { pressed: v > 0.1, touched: v > 0, value: v };
        _state.timestamp = performance.now();
    };

    // ── Patch Navigator.getGamepads() ────────────────────────────────────────
    const _originalGetGamepads = navigator.getGamepads
        ? navigator.getGamepads.bind(navigator)
        : () => [null, null, null, null];

    navigator.getGamepads = function () {
        // Build a read-only Gamepad-like object from _state
        const gp = Object.freeze({
            id: _state.id,
            index: _state.index,
            connected: _state.connected,
            mapping: _state.mapping,
            timestamp: _state.timestamp,
            axes: Object.freeze(Array.from(_state.axes)),
            buttons: Object.freeze(_state.buttons.map(b =>
                Object.freeze({ pressed: b.pressed, touched: b.touched, value: b.value })
            )),
            hapticActuators: _state.hapticActuators,
            vibrationActuator: _state.vibrationActuator,
        });
        return [gp, null, null, null];
    };

    // ── Fire gamepadconnected event ──────────────────────────────────────────
    // xCloud checks for this event to know a controller is available
    setTimeout(() => {
        window.dispatchEvent(new GamepadEvent('gamepadconnected', {
            gamepad: navigator.getGamepads()[0],
        }));
        console.log('[Better xCloud iOS] Virtual gamepad connected ✓');
    }, 800);

    // ── Reconnect on page navigation (xCloud is a SPA) ──────────────────────
    const _reconnect = () => {
        setTimeout(() => {
            if (_state.connected) {
                window.dispatchEvent(new GamepadEvent('gamepadconnected', {
                    gamepad: navigator.getGamepads()[0],
                }));
            }
        }, 1200);
    };
    window.addEventListener('popstate', _reconnect);

})();
