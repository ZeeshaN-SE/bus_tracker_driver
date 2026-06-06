# Driver App — Testing Guide (Phase 6)

## Prerequisites

1. **Backend running:** `cd backend && npm run dev`
2. **Scheduled trip exists:** Run `node database/setup.js` (seeds 5 buses, 3 routes, 2 drivers, scheduled trips)
3. **Student app available** (optional — to verify live tracking integration)
4. **Android device or emulator** connected (`flutter devices`)

---

## Setup

```bash
cd bus_tracker_driver
flutter pub get
flutter run
```

> **Physical device?** Update `lib/core/constants/api_constants.dart`:
> ```dart
> static const String baseUrl = 'http://192.168.x.x:3000/api/';
> ```
> (Use your PC's LAN IP — run `ipconfig | findstr IPv4` to find it)

---

## Test 1: Splash Screen

- Launch the app
- Should see green splash screen with bus icon + "Driver App" subtitle
- After ~1.5 seconds, redirects to Login (if not logged in)

---

## Test 2: Login — Driver Credentials ✅

1. Enter: `driver1@test.com` / `Test@123`
2. Tap **Login**
3. Expected: navigates to **Dashboard** (My Trips)

## Test 3: Login — Student Credentials Rejected ❌

1. Enter: `student1@test.com` / `Test@123`
2. Tap **Login**
3. Expected: error message **"This app is for drivers only"**
4. Token should be cleared (not stored)

## Test 4: Login — Wrong Password ❌

1. Enter: `driver1@test.com` / `WrongPass`
2. Expected: error message from server

---

## Test 5: Dashboard

1. Login as `driver1@test.com`
2. Expected: list of trips assigned to driver1
3. Verify:
   - Route name + code displayed
   - Bus number displayed
   - Scheduled time displayed
   - Status chip colour-coded:
     - `scheduled` → blue
     - `in_progress` → green
     - `completed` → grey
     - `cancelled` → red

### Filter Chips

- Tap **Scheduled** → shows only scheduled trips
- Tap **In Progress** → shows only active trips
- Tap **Today** → shows today's trips
- Tap **All** → shows all trips
- Pull down → refreshes list
- Tap FAB (refresh icon) → manual refresh

---

## Test 6: Start Trip

1. Find a trip with status `scheduled` → tap **Start Trip**
2. Expected: location permission dialog appears
   - Grant **"Allow all the time"** (or "While using the app" for testing)
3. Expected: navigates to **Active Trip** screen
4. **Android:** Notification "Trip in Progress" appears in status bar

### If permission denied:

- SnackBar: "Location permission required to start a trip."

---

## Test 7: Active Trip Screen

1. Verify trip info card shows:
   - Route name + code
   - Bus number
   - Start time
2. GPS Status card:
   - Green dot + "GPS Active" when tracking starts
   - "Last Update: HH:MM:SS" updates every ~10 seconds
   - Lat/lng coordinates displayed
3. Back button shows dialog: "Trip is Active — End trip before leaving?"

---

## Test 8: GPS Tracking Verification

Check the database directly:

```sql
-- Connect to DB
psql -U postgres -d bus_tracker

-- Check recent GPS records
SELECT trip_id, latitude, longitude, speed, timestamp
FROM gps_tracking
ORDER BY timestamp DESC
LIMIT 10;
```

Expected: new rows appearing every ~10 seconds.

---

## Test 9: Background Tracking

1. While on Active Trip screen, press **Home** (minimize app)
2. Android notification "Trip in Progress" remains visible
3. Wait 20–30 seconds
4. Re-open app → "Last Update" time should have advanced
5. Check DB again → new GPS rows added while app was in background

> **If tracking stops in background:**
> Go to Settings → Apps → Bus Tracker Driver → Battery → select **Unrestricted**

---

## Test 10: End Trip (from screen)

1. On Active Trip screen, tap red **End Trip** button
2. Confirmation dialog appears: "Are you sure you want to end this trip?"
3. Tap **End Trip** to confirm
4. Expected:
   - GPS service stops
   - Notification disappears
   - Returns to Dashboard
   - Trip status changes to `completed` (grey chip)

---

## Test 11: End Trip (from notification)

1. While on Active Trip screen or with app in background
2. Tap **End Trip** button in the Android notification
3. Expected: confirmation dialog appears in app
4. Confirm → trip ends, returns to Dashboard

---

## Test 12: Resume In-Progress Trip

1. If app is killed while a trip is `in_progress`
2. Re-login → Dashboard shows trip with **Resume** button (orange)
3. Tap **Resume** → opens Active Trip screen
4. GPS tracking restarts

---

## Integration Test: Driver App + Student App

1. Start backend: `cd backend && npm run dev`
2. Open **Driver App** → login → start a trip
3. Open **Student App** → go to **Map** tab
4. Expected: blue bus marker visible on map, updating every 10 seconds

---

## Common Issues & Fixes

| Problem | Fix |
|---------|-----|
| `Connection refused` | Backend not running, or wrong `baseUrl` in `api_constants.dart` |
| Location not updating | Grant "Allow all the time" permission in device Settings |
| GPS stops in background | Disable battery optimization: Settings → Apps → Bus Tracker Driver → Battery → Unrestricted |
| Can't start trip | Trip must be in `scheduled` status — check DB or run `node database/setup.js` again |
| `401 Unauthorized` on GPS | Token expired — logout and login again |
| Grey map tiles (if map shown) | Invalid Google Maps API key — check `AndroidManifest.xml` |
| `MissingPluginException` | Run `flutter clean && flutter pub get && flutter run` |
| Notification not showing | Check FOREGROUND_SERVICE permissions in AndroidManifest.xml |

---

## Seeding a Scheduled Trip

If no scheduled trips exist:

```bash
cd backend

# Option 1: Full DB reset (creates fresh scheduled trips)
node database/setup.js

# Option 2: Check existing trips in DB
psql -U postgres -d bus_tracker -c "SELECT id, status, scheduled_time FROM trips WHERE status = 'scheduled';"
```

---

## Phase 6 Completion Checklist

- [ ] Driver app builds and runs (`flutter run`)
- [ ] Green splash screen with "Driver App" subtitle
- [ ] Login works with `driver1@test.com` / `Test@123`
- [ ] Non-driver login rejected with clear error message
- [ ] Dashboard shows assigned trips with correct status chips
- [ ] Filter chips work (All, Today, Scheduled, In Progress)
- [ ] Pull-to-refresh reloads trips
- [ ] Start Trip requests location permission
- [ ] Active Trip screen shows GPS status updating every ~10 seconds
- [ ] Android foreground notification appears during active trip
- [ ] GPS records appear in `gps_tracking` table (check DB)
- [ ] Background tracking continues when app is minimised
- [ ] End Trip from screen works (confirmation dialog → Dashboard)
- [ ] End Trip from notification works
- [ ] Student app Map tab shows moving bus marker during active driver trip

**Integration verified:** Driver starts trip → Student app Map tab → bus marker visible and moving ✅
