# Flutter App

See the root `README.md` for the merged project overview and full run instructions.

This Flutter app now includes:

- Offline recommendation and browsing features from `tourism_app.zip`
- A unified recommendation screen that tries the AI backend first and falls back offline automatically
- Runtime backend URL support through `--dart-define`

Do not put Groq, Gemini, Anthropic, or other server-side AI provider keys in
the Flutter app. Mobile app assets can be extracted from an APK. Keep those
keys in `backend/.env` and let the app call the FastAPI backend.

Run with a phone-reachable backend URL:

```powershell
flutter run `
  --dart-define=AI_BACKEND_BASE_URL=http://192.168.x.x:8000
```

Build a release APK with a public backend URL:

```powershell
flutter build apk --release `
  --dart-define=AI_BACKEND_BASE_URL=https://your-public-backend.example.com
```

The `192.168.x.x` URL is only for same-Wi-Fi development. A release APK that
works on any Wi-Fi or mobile data needs a public HTTPS backend URL.

For Android emulator, the backend URL defaults to `http://10.0.2.2:8000`.

Pass Flutter arguments normally when needed:

```powershell
flutter run -d chrome `
  --dart-define=AI_BACKEND_BASE_URL=http://127.0.0.1:8000
```
