# Flutter App

See the root `README.md` for the merged project overview and full run instructions.

This Flutter app now includes:

- Offline recommendation and browsing features from `tourism_app.zip`
- A unified recommendation screen that tries the AI backend first and falls back offline automatically
- Local `.env` support through `run_with_env.ps1` for the backend URL

Run with the saved backend URL in `app/.env`:

```powershell
.\run_with_env.ps1
```

Pass Flutter arguments after it when needed:

```powershell
.\run_with_env.ps1 -d chrome
```

Override the saved URL for one run:

```powershell
.\run_with_env.ps1 --backend-url http://192.168.18.132:8000
```
