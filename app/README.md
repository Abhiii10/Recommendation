# Flutter App

See the root `README.md` for the merged project overview and full run instructions.

This Flutter app now includes:

- Offline recommendation and browsing features from `tourism_app.zip`
- A unified recommendation screen that tries the AI backend first and falls back offline automatically
- Runtime backend URL and key support through `--dart-define`

Run with a phone-reachable backend URL:

```powershell
flutter run `
  --dart-define=ANTHROPIC_API_KEY=sk-ant-... `
  --dart-define=AI_BACKEND_BASE_URL=http://192.168.x.x:8000
```

For Android emulator, the backend URL defaults to `http://10.0.2.2:8000`.

Pass Flutter arguments normally when needed:

```powershell
flutter run -d chrome `
  --dart-define=ANTHROPIC_API_KEY=sk-ant-... `
  --dart-define=AI_BACKEND_BASE_URL=http://127.0.0.1:8000
```
