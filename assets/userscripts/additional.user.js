/* ============================================================
 * Better xCloud – iOS Enhanced Userscript (v3.0.0)
 * Injected by bxc_app_ios Flutter wrapper
 * ============================================================ */

(function () {
    'use strict';

    if (!window.location.pathname.includes('/play') &&
        !window.location.pathname.includes('/auth')) {
        return;
    }

    const bxFlags = [[BX_FLAGS]] || {};
    window.BX_FLAGS = Object.assign({}, bxFlags);

    // ── 1. iOS Compatibility Patches ─────────────────────────────────────────

    // Battery API Patch (WKWebView lacks it)
    if (!('getBattery' in navigator)) {
        Object.defineProperty(navigator, 'getBattery', {
            value: () => Promise.resolve({
                charging: true,
                level: 1.0,
                chargingTime: 0,
                dischargingTime: Infinity,
                onchargingchange: null,
                onlevelchange: null,
                addEventListener: () => { },
                removeEventListener: () => { },
            }),
        });
    }

    // Vibration API Patch
    if (!('vibrate' in navigator)) {
        navigator.vibrate = () => true;
    }

    // Gamepad Vibration Patch
    const _origGetGamepads = navigator.getGamepads.bind(navigator);
    navigator.getGamepads = function () {
        const gamepads = _origGetGamepads();
        return Array.from(gamepads).map(gp => {
            if (gp && !gp.vibrationActuator) {
                Object.defineProperty(gp, 'vibrationActuator', {
                    value: {
                        type: 'dual-rumble',
                        playEffect: () => Promise.resolve('complete'),
                        reset: () => Promise.resolve('complete'),
                    },
                    configurable: true,
                });
            }
            return gp;
        });
    };

    // ── 2. Stream Quality & Bitrate ──────────────────────────────────────────

    // Skip Splash Video
    if (bxFlags.SkipSplashVideo) {
        const _origFetch = window.fetch.bind(window);
        window.fetch = async function (input, init) {
            const url = (typeof input === 'string') ? input : input.url;
            if (url?.includes('/configuration') && url?.includes('xhome')) {
                const res = await _origFetch(input, init);
                try {
                    const json = await res.clone().json();
                    if (json?.settings) {
                        json.settings.startupScreenDelay = 0;
                        json.settings.showSplashScreen = false;
                    }
                    return new Response(JSON.stringify(json), res);
                } catch (_) { }
                return res;
            }
            return _origFetch(input, init);
        };
    }

    // 1080p, Codec, and Bitrate Control
    if (bxFlags.PreferHighQuality || bxFlags.MaxBitrate) {
        const _OrigRTCPeer = window.RTCPeerConnection;
        window.RTCPeerConnection = function (config, constraints) {
            const pc = new _OrigRTCPeer(config, constraints);
            const _setRemote = pc.setRemoteDescription.bind(pc);

            pc.setRemoteDescription = function (desc) {
                if (desc?.sdp) {
                    let sdp = desc.sdp;

                    // Codec: Force H.264 High Profile
                    if (bxFlags.PreferHighQuality) {
                        sdp = sdp.replace(/profile-level-id=42[0-9a-fA-F]{4}/g, 'profile-level-id=640c34');
                    }

                    // Resolution: Prefer 1080p
                    if (bxFlags.PreferHighQuality) {
                        sdp = sdp.replace(/a=imageattr:(\d+) send \[x=\[(\d+):(\d+)\],y=\[(\d+):(\d+)\]/g,
                            (m, pt) => `a=imageattr:${pt} send [x=[320:1920],y=[180:1080]`);
                    }

                    // Bitrate: Inject b=AS line
                    if (bxFlags.MaxBitrate && bxFlags.MaxBitrate > 0) {
                        const bitrateKbps = bxFlags.MaxBitrate * 1000;
                        sdp = sdp.replace(/(m=video.*\r?\n)/g, `$1b=AS:${bitrateKbps}\r\n`);
                    }

                    return _setRemote({ type: desc.type, sdp });
                }
                return _setRemote(desc);
            };
            return pc;
        };
        window.RTCPeerConnection.prototype = _OrigRTCPeer.prototype;
    }

    // ── 3. Video & Audio Enhancements ────────────────────────────────────────

    // Clarity Boost & Filters
    function updateVideoStyles() {
        const existing = document.getElementById('bxc-video-styles');
        if (existing) existing.remove();

        const style = document.createElement('style');
        style.id = 'bxc-video-styles';

        let filters = [];
        if (bxFlags.VideoFilter) {
            const f = bxFlags.VideoFilter;
            if (f.brightness !== 1) filters.push(`brightness(${f.brightness})`);
            if (f.contrast !== 1) filters.push(`contrast(${f.contrast})`);
            if (f.saturation !== 1) filters.push(`saturate(${f.saturation})`);
        }

        if (bxFlags.ClarityBoost?.enabled) {
            const level = bxFlags.ClarityBoost.level || 1;
            filters.push(`contrast(${1 + level * 0.08})`);
            filters.push(`saturate(${1 + level * 0.05})`);
        }

        const filterStr = filters.length ? `filter: ${filters.join(' ')} !important; -webkit-filter: ${filters.join(' ')} !important;` : '';
        const renderingStr = bxFlags.ClarityBoost?.enabled ? 'image-rendering: -webkit-optimize-contrast !important;' : '';

        let objectFit = 'contain';
        if (bxFlags.AspectRatio === 'fill') objectFit = 'fill';
        if (bxFlags.AspectRatio === 'cover') objectFit = 'cover';

        style.textContent = `
            video {
                ${renderingStr}
                ${filterStr}
                object-fit: ${objectFit} !important;
                transform: translateZ(0);
            }
        `;
        document.head.appendChild(style);
    }

    // Volume Boost (AudioContext)
    let audioCtx, gainNode, audioSource;
    function applyVolumeBoost() {
        if (!bxFlags.VolumeBoost || bxFlags.VolumeBoost <= 1) return;

        // Find video element periodically until it exists
        const interval = setInterval(() => {
            const video = document.querySelector('video');
            if (video && !audioCtx) {
                clearInterval(interval);
                try {
                    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
                    gainNode = audioCtx.createGain();
                    audioSource = audioCtx.createMediaElementSource(video);
                    audioSource.connect(gainNode);
                    gainNode.connect(audioCtx.destination);
                    gainNode.gain.value = bxFlags.VolumeBoost;
                    console.log(`[BxC] Volume boost applied: ${bxFlags.VolumeBoost}x`);
                } catch (e) { console.error('[BxC] Audio boost failed', e); }
            }
        }, 1000);
    }

    // ── 4. UI & Privacy ──────────────────────────────────────────────────────

    // UI Tweaks (Hide sections, simplify menu)
    function applyUiTweaks() {
        const style = document.createElement('style');
        style.id = 'bxc-ui-tweaks';
        let css = '';

        if (bxFlags.DisableSocialFeatures) {
            css += '[data-testid="SocialPanel"], [data-testid="FriendsButton"] { display: none !important; }';
        }
        if (bxFlags.SimplifyStreamMenu) {
            css += '.stream-menu-button-label { display: none !important; }';
        }
        if (bxFlags.HideSystemMenuIcon) {
            css += 'button[class*="SystemMenu"] { opacity: 0 !important; }';
        }
        if (bxFlags.ReduceAnimations) {
            css += '*, *::before, *::after { transition: none !important; animation: none !important; }';
        }

        style.textContent = css;
        document.head.appendChild(style);
    }

    // Privacy: Block Analytics
    if (bxFlags.DisableAnalytics) {
        const _origFetch = window.fetch.bind(window);
        window.fetch = function (input, init) {
            const url = (typeof input === 'string') ? input : input.url;
            if (url?.includes('analytics') || url?.includes('telemetry')) {
                return Promise.resolve(new Response(null, { status: 204 }));
            }
            return _origFetch(input, init);
        };
    }

    // ── 5. Stats & HUD ───────────────────────────────────────────────────────

    window.bxcStats = {
        playtime: 0,
        startTime: Date.now()
    };

    // Advanced Stats Interceptor
    const _orgStats = RTCPeerConnection.prototype.getStats;
    RTCPeerConnection.prototype.getStats = async function () {
        const report = await _orgStats.call(this);
        const stats = {
            fps: 0, rtt: 0, bytes: 0, loss: 0, jitter: 0,
            playtime: Math.floor((Date.now() - window.bxcStats.startTime) / 1000)
        };

        report.forEach(s => {
            if (s.type === 'inbound-rtp' && s.mediaType === 'video') {
                stats.fps = s.framesPerSecond || 0;
                stats.bytes = s.bytesReceived || 0;
                stats.loss = s.packetsLost || 0;
                stats.jitter = s.jitter || 0;
            }
            if (s.type === 'candidate-pair' && s.state === 'succeeded') {
                stats.rtt = Math.round((s.currentRoundTripTime || 0) * 1000);
            }
        });

        if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('onStreamStats', JSON.stringify(stats));
        }
        return report;
    };

    // ── Init ────────────────────────────────────────────────────────────────

    function init() {
        updateVideoStyles();
        applyUiTweaks();
        applyVolumeBoost();
        console.log('[Better xCloud iOS] v3.0.0 Ready ✓');
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    // Bridge for live testing
    window.bxcBridge = {
        updateStyles: updateVideoStyles,
        reload: () => window.location.reload()
    };
})();
