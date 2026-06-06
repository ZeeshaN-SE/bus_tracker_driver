# Bus Tracker — Driver App

Flutter app for university bus drivers. Real-time GPS tracking, trip management, and student pass QR scanning.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x)
- Android Studio or VS Code with Flutter extension
- Backend server running (ask admin for IP)

## Setup (First Time)

```bash
# 1. Clone the repo
git clone https://github.com/ZeeshaN-SE/bus_tracker_driver.git
cd bus_tracker_driver

# 2. Install dependencies
flutter pub get

# 3. Set backend URL — open lib/core/constants/api_constants.dart
#    Change BASE_URL to your backend server's IP (e.g., http://192.168.x.x:3000/api/)

# 4. Run on connected device or emulator
flutter run
```

## How to Collaborate

### One-time setup
```bash
# Clone (only once)
git clone https://github.com/ZeeshaN-SE/bus_tracker_driver.git
cd bus_tracker_driver
```

### Every time you work on a feature
```bash
# 1. Get latest code
git pull origin master

# 2. Create a branch for your work
git checkout -b feature/your-feature-name

# 3. Make your changes, then commit
git add .
git commit -m "Added: short description of what you did"

# 4. Push your branch to GitHub
git push origin feature/your-feature-name

# 5. Go to the repo page on GitHub → create a Pull Request
#    https://github.com/ZeeshaN-SE/bus_tracker_driver
```

### Golden rules
- Never commit directly to `master`
- Always `git pull` before starting new work
- Use clear branch names (e.g., `feature/qr-fix`, `fix/gps-crash`)
- Write short, meaningful commit messages
- After model changes, run: `flutter pub run build_runner build --delete-conflicting-outputs`

## Test Login
| Email | Password |
|---|---|
| driver1@test.com | Test@123 |
| driver2@test.com | Test@123 |

## Need Help?
Open an issue on GitHub or ask in the group chat.
