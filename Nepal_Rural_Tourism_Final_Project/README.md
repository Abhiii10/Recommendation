# Nepal Rural Tourism Final Project

This folder combines the two projects you shared into one submission-ready project:

- The full Flutter application shell comes from `tourism_app.zip`
- The FastAPI recommendation backend, evaluation code, and API flow come from `TourismProject.zip`

## What is included

- `app/`
  Full Flutter project with offline browsing, saved destinations, map view, translation support, and one unified recommendation flow:
  - `Recommend`: AI-first recommendations with automatic offline fallback
- `backend/`
  FastAPI backend for AI recommendations, interactions, similar destinations, and accommodations
- `data/`
  Backend JSON datasets
- `evaluation/`
  Evaluation and benchmarking utilities for the backend recommender
- `requirements.txt`
  Python dependencies for the backend

## How to run the backend

1. Open a terminal in the project root.
2. Create and activate a virtual environment.
3. Install dependencies:

```bash
pip install -r requirements.txt
```

4. Start the API server:

```bash
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

5. Open the API docs:

```text
http://127.0.0.1:8000/docs
```

## How to run the Flutter app

1. Open a terminal in `app/`
2. Install packages:

```bash
flutter pub get
```

3. Check `.env`

`app/.env.example` shows the expected values:

```text
HF_TOKEN=
AI_BACKEND_BASE_URL=http://10.0.2.2:8000
```

Use these backend URL defaults:

- Android emulator: `http://10.0.2.2:8000`
- Windows desktop, web, or iOS simulator: `http://127.0.0.1:8000`
- Physical device: `http://<your-lan-ip>:8000`

4. Run the app:

```bash
flutter run
```

## Dataset sync

The Flutter app now supports a synced backend dataset asset:

- Backend source: `data/destinations.json`
- Synced app asset: `app/assets/data/backend_destinations.json`

To sync the dataset manually:

```bash
bash ./scripts/sync_backend_data.sh
```

## Main merged improvements

- Kept the richer Flutter scaffold, navigation, assets, and offline recommender from the first archive
- Unified the two recommenders into a single `Recommend` experience
- Backend AI is tried first and falls back automatically to the offline recommender on failure
- Added a visible mode badge so users can see `AI Recommendations` or `Offline Mode`
- Synced backend destination data into the Flutter app asset pipeline
- Added AI destination detail views with score breakdown, similar destinations, and accommodation data
- Moved sensitive token storage to a safe placeholder in the delivered `.env`

## Notes

- The app now shows a single recommendation screen even though it still keeps both engines internally.
- If the backend is unavailable, the recommendation screen automatically switches to offline mode.
- For mobile devices, set `AI_BACKEND_BASE_URL` in `app/.env` to your PC LAN IP, not `127.0.0.1`.
