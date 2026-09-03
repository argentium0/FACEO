# FACEO Ephemeral Rooms — Failure-Mode Testing Protocol

## Overview & Architecture
This document details manual verification procedures to validate the **Burn-After-Meeting** (Ephemeral Rooms) architecture operating on the **Firebase Spark Plan** (100% free tier).

The architecture relies on three defense layers:
1. **Client Disconnect Hook (`onDisconnect`)**: Realtime Database automatically sets the `emptyAt` server timestamp under `/rooms/{roomId}/emptyAt` when the active participant count reaches 0.
2. **Security Rule Lockouts (`firestore.rules` & `database.rules.json`)**: After 5 minutes from `emptyAt`, read and update/join permissions are strictly denied by security rules. Deletion (`newData.val() == null` in RTDB / `allow delete` in Firestore) remains permitted.
3. **Decentralized Client Sweeper (`RoomSweeperService`)**: Any client app launch executes a background sweep querying for expired rooms (`emptyAt + 5 mins < now`) and purges their Firestore documents and RTDB nodes.

---

## Test Protocol Specifications

### Test Case A: App Force-Killed Mid-Call
**Objective:** Verify that force-killing the app when participant count reaches 0 correctly triggers RTDB `onDisconnect` server hook and writes `emptyAt`.

#### Pre-conditions:
- Two test devices (Client A and Client B) or one active client on a room where all other participants leave.
- Firebase Console (Realtime Database & Firestore viewers) open.

#### Execution Steps:
1. Client A creates room `room-test-forcekill` and joins call.
2. Client B joins room `room-test-forcekill`.
3. Client B leaves call gracefully via the End Call button (`participantCount = 1`).
4. Force-kill the Client A application process (Swipe away from recent apps / `adb shell am force-stop`).

#### Expected Results:
1. RTDB node `/presence/room-test-forcekill/ClientA` automatically changes state to `offline` via `onDisconnect()`.
2. RTDB node `/rooms/room-test-forcekill/emptyAt` is created with the current server timestamp.
3. Firestore document `/rooms/room-test-forcekill` retains `emptyAt` timestamp.

---

### Test Case B: Device Switched to Airplane Mode Mid-Call
**Objective:** Verify that abrupt network connection loss triggers server-side socket termination and writes `emptyAt`.

#### Pre-conditions:
- Client device connected to room `room-test-airplane`.
- Firebase Console RTDB viewer active.

#### Execution Steps:
1. Client joins `room-test-airplane` as the sole participant.
2. Toggle **Airplane Mode ON** on the device mid-call.
3. Wait 30–60 seconds for Firebase Realtime Database socket timeout detection.

#### Expected Results:
1. RTDB server registers socket drop and executes `onDisconnect()` handler.
2. Node `/rooms/room-test-airplane/emptyAt` is set to server timestamp.
3. Re-enabling WiFi on device and attempting to rejoin within 5 minutes displays the **Countdown Banner** in `CallScreen1v1`, which immediately cancels and clears `emptyAt` upon presence re-establishment.

---

### Test Case C: Client Sweeper & 5-Minute Lockout Execution
**Objective:** Verify that 5 minutes after `emptyAt`, security rules deny read/join operations and `RoomSweeperService` purges room data.

#### Pre-conditions:
- An empty room `room-test-expiry` with `emptyAt` timestamp set > 5 minutes ago (300,000 ms).

#### Execution Steps:
1. Manually inspect or set `emptyAt` to `now - 6 minutes` in RTDB.
2. Attempt to join `room-test-expiry` from a client application.
3. Launch FACEO application on any client device (`RoomSweeperService().sweepExpiredRooms()`).

#### Expected Results:
1. Join attempt is denied by `joinRoomPresence()` check and Firebase Security Rules with a permission/expired error snackbar.
2. `RoomSweeperService` executes batch deletion on Firestore `/rooms/room-test-expiry` and RTDB `/rooms/room-test-expiry`, `/presence/room-test-expiry`, `/activeSpeaker/room-test-expiry`.
3. Database storage usage returns to 0 bytes for the purged room.

---

## Verification Commands & Log Auditing

### Check Firestore Security Rule Test via Firebase CLI:
```bash
firebase emulators:start --only firestore,database
```

### Inspect Local Dart Compilation & Analyzer Integrity:
```bash
flutter analyze lib/ui/widgets/countdown_banner.dart lib/ui/screens/call_screen_1v1.dart lib/services/room_sweeper_service.dart
```
