# FACEO — Field Network Throttling & Hysteresis Testing Protocol

This document defines the manual testing procedure to validate **Phase 4 (Audio-First Fallback & On-Device Live Captions)** under real-world degraded network conditions using Android Emulator cellular controls and iOS Network Link Conditioner.

---

## 1. Objectives

1. **Validate Degrade Fast Rule:** Confirm that when network quality drops to `Bad` or `Die` for > 2 consecutive callbacks (~4 seconds), video publishing mutes, and the `AudioFirstOverlay` with live captions mounts immediately.
2. **Validate Recover Slow Rule:** Confirm that when network quality returns to `Excellent`, the system remains in audio-fallback mode for **exactly 5 consecutive Excellent callbacks** (~10–12 seconds) before restoring video rendering, preventing jarring video toggling.
3. **Verify Audio Continuity & Live Captions:** Ensure active audio streaming remains uninterrupted during stream switching and live transcript captions are rendered in Neon Yellow (`#F6FF7F`).

---

## 2. Environment Setup

### A. Android Emulator Cellular Throttle
1. Launch the Android Emulator running the FACEO debug build.
2. Open Emulator Control Panel: Click the **Three Dots (...)** icon on the emulator toolbar.
3. Navigate to **Cellular** in the left menu.
4. Set **Network Type**:
   - **Degraded Mode Test:** Select `EDGE` or `GPRS`.
   - **Recovery Mode Test:** Select `LTE` or `Full`.
5. Set **Signal Strength**: Select `Poor` or `Moderate`.
6. *(Alternative via Command Line)*:
   ```bash
   emulator -avd <AVD_NAME> -netdelay gprs -netspeed gprs
   ```

---

### B. iOS Developer Network Link Conditioner
1. Connect target iOS device to Mac running Xcode or launch iOS Simulator.
2. Open **Settings** on iOS Device / Simulator -> **Developer** -> **Network Link Conditioner**.
3. Select Profile:
   - **Degraded Mode Test:** Select `Very Bad Network` (100% Loss or High Packet Loss) or `EDGE`.
   - **Custom Degraded Profile Parameters:**
     - Downlink Bandwidth: `56 kbps`
     - Uplink Bandwidth: `56 kbps`
     - Downlink Delay: `400 ms`
     - Uplink Delay: `400 ms`
     - Packet Loss: `15%`
   - **Recovery Mode Test:** Set Network Link Conditioner to `OFF` or select `Wi-Fi`.

---

## 3. Step-by-Step Field Test Execution

| Step | Action | Expected Behavior | Pass Criteria |
| :--- | :--- | :--- | :--- |
| **1. Session Init** | Launch 1-on-1 call between two devices on normal Wi-Fi / LTE network. | Fullscreen remote video and local PIP canvas render smoothly. | Video stream active on both sides. |
| **2. Trigger Degradation** | Enable `EDGE` / `Very Bad Network` throttle on Device A. | Zego engine emits `Bad`/`Die` network quality callbacks. | 1st & 2nd bad callbacks do NOT trigger fallback yet. |
| **3. Degrade Fast Check** | Maintain throttled connection for > 4 seconds (3rd consecutive Bad callback). | `isAudioOnlyFallbackActive` transitions to `true`. Local outgoing video mutes. | `AudioFirstOverlay` mounts over canvas with Neon Yellow (#F6FF7F) captions. |
| **4. Speech Verification** | Speak into Device A microphone during fallback. | Speech-to-Text engine captures voice input. | Real-time recognized text appears in live captions card. |
| **5. Anti-Flicker Interruption** | Briefly turn off throttle for 2 seconds (1-2 Excellent callbacks) then re-throttle. | System counts Excellent callbacks but does NOT exit fallback mode. | Fallback remains active; video does NOT flicker on. |
| **6. Trigger Recovery** | Completely disable network throttle (restore Wi-Fi / LTE). | Zego engine emits `Excellent` callbacks. | Readings 1 through 4 keep fallback ACTIVE. |
| **7. Recover Slow Check** | Maintain `Excellent` network for 5 consecutive callbacks (~10-12 seconds). | On 5th consecutive Excellent callback, `isAudioOnlyFallbackActive` transitions to `false`. | `AudioFirstOverlay` unmounts cleanly; video publishing & rendering resume. |

---

## 4. Expected Behavior Verification Matrix

```
[Normal Mode: Video Active] 
       │ 
  (Quality Bad / Die) 
       │ 
  Reading 1 ──> Counter = 1 (Fallback: FALSE)
  Reading 2 ──> Counter = 2 (Fallback: FALSE)
  Reading 3 ──> Counter = 3 (> 2) ──> [DEGRADE FAST: Fallback = TRUE]
                                            │
                                  (Audio-First Overlay Active)
                                  (Live Captions in Neon Yellow)
                                            │
                                    (Network Restored)
                                            │
                                  Reading 1 ──> Counter = 1 (Fallback: TRUE)
                                  Reading 2 ──> Counter = 2 (Fallback: TRUE)
                                  Reading 3 ──> Counter = 3 (Fallback: TRUE)
                                  Reading 4 ──> Counter = 4 (Fallback: TRUE)
                                  Reading 5 ──> [RECOVER SLOW: Fallback = FALSE]
                                            │
                                 [Normal Mode Restored]
```
