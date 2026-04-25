
````markdown
# 🇳🇵 Nepal Rural Tourism Recommendation System

## 📌 Overview

The **Nepal Rural Tourism Recommendation System** is an AI-powered mobile and backend system designed to promote rural destinations in Nepal.

It uses a **hybrid recommendation approach** that combines:

- SBERT semantic retrieval
- Collaborative filtering
- Popularity fallback for cold-start users
- Contextual reranking
- Offline local recommendation
- Cached AI recommendation fallback
- Explainable score breakdown

The system is built with a **Flutter mobile app** and a **FastAPI backend**.

---

## 🧠 System Architecture

```text
User Preferences
        ↓
Preference Query Builder
        ↓
SBERT Semantic Candidate Retrieval
        ↓
Collaborative Filtering
        ↓
Cold-Start Popularity Fallback
        ↓
Contextual Reranking
        ↓
Diversity Filtering
        ↓
Explainable Recommendations
````

---

## ⚙️ Tech Stack

### Backend

* Python
* FastAPI
* Sentence Transformers / SBERT
* Scikit-learn
* Pydantic
* JSON-based storage

### Frontend

* Flutter
* Dart
* SQLite / local storage
* SharedPreferences
* REST API integration
* Offline-first recommendation fallback

---

## 🚀 Features

* 🔍 Semantic destination search using SBERT
* 🤝 Collaborative filtering from user interactions
* 🔥 Popularity fallback for new/cold-start users
* 🎯 Context-aware ranking using activity, budget, season, vibe, accessibility, family-friendliness, and accommodation fit
* 📱 Hybrid online/offline recommendation system
* 💾 Cached AI recommendations when backend is unavailable
* 🧠 Local offline personalization using user affinity
* 🗺️ Map-based destination exploration
* 🧾 Explainable recommendation reasons
* 📊 Evaluation metrics for recommendation quality

---

## 📂 Project Structure

```text
app/          Flutter mobile application
backend/      FastAPI recommendation backend
data/         JSON datasets
evaluation/   Recommendation metrics and benchmark scripts
scripts/      Utility scripts
README.md     Project documentation
```

---

## 🧠 Recommendation System

### Online Recommendation Pipeline

The online backend recommender works in multiple stages:

```text
User Input
   ↓
SBERT Semantic Retrieval
   ↓
Collaborative Filtering
   ↓
Popularity Fallback
   ↓
Contextual Reranking
   ↓
Final Recommendation + Explanation
```

### 1. Semantic Retrieval

The system converts user preferences into a natural-language query and compares it with destination descriptions using SBERT embeddings.

Example user profile:

```text
Activity: trekking
Budget: medium
Season: autumn
Vibe: adventure
Family Friendly: true
Adventure Level: 4
```

The backend retrieves semantically similar destinations even when exact keywords do not match.

---

### 2. Collaborative Filtering

The system uses user interaction data to recommend destinations based on similar user behavior.

Interaction examples:

```text
view
save
click
recommendation_saved
```

This allows the system to personalize recommendations over time.

---

### 3. Cold-Start Popularity Fallback

For new users with no interaction history, collaborative filtering may not have enough data.

To solve this, the system uses a popularity fallback:

```text
Cold-start user:
final collaborative signal = popularity score

Warm user:
final collaborative signal = 75% collaborative + 25% popularity
```

This prevents new users from receiving weak or empty personalization signals.

---

### 4. Contextual Reranking

After candidate retrieval, the system reranks destinations using contextual signals:

* Activity match
* Vibe match
* Season match
* Budget match
* Accessibility fit
* Family-friendliness
* Accommodation availability

Final score:

```text
Final Score =
0.50 × Semantic Score
+ 0.20 × Collaborative / Popularity Score
+ 0.30 × Contextual Score
```

---

### 5. Explainable Recommendations

Each recommendation includes reasons explaining why it was selected.

Example:

```text
- Strong semantic match for trekking with adventure atmosphere
- Best season match for autumn
- Fits your medium budget
```

This makes the recommender transparent and easier to justify during evaluation.

---

## 📱 Offline Recommendation System

The Flutter app also supports offline recommendations.

Offline mode uses:

* Local destination data
* TF-IDF-style text similarity
* Numeric feature matching
* Contextual scoring
* Local user affinity
* Cached AI recommendations

Offline pipeline:

```text
Backend unavailable
        ↓
Check cached AI recommendations
        ↓
If cache exists, show cached AI results
        ↓
If no cache exists, use advanced offline recommender
        ↓
Return explainable offline recommendations
```

This means the app does not become useless when the backend is unavailable.

---

## 💾 Cached AI Fallback

When online recommendations are successful, the app stores them locally.

If the backend later becomes unavailable, the app first shows cached AI recommendations before falling back to fully offline scoring.

Cache strategy:

```text
Successful AI recommendation
        ↓
Saved locally
        ↓
Backend unavailable
        ↓
Cached AI result shown
```

This improves reliability during demos and real-world usage.

---

## ▶️ How to Run

## Backend

From the project root:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

Backend health check:

```text
http://127.0.0.1:8000/health
```

Expected response:

```json
{
  "status": "healthy"
}
```

API documentation:

```text
http://127.0.0.1:8000/docs
```

---

## Android Phone Setup

For a real Android phone, the backend URL must use the laptop Wi-Fi IPv4 address.

Check your laptop IP:

```powershell
ipconfig
```

Find the Wi-Fi IPv4 address, for example:

```text
192.168.18.132
```

Then set `app/.env`:

```env
AI_BACKEND_BASE_URL=http://192.168.18.132:8000
```

Allow Windows firewall access:

```powershell
netsh advfirewall firewall add rule name="FastAPI 8000" dir=in action=allow protocol=TCP localport=8000
```

Test from phone browser:

```text
http://192.168.18.132:8000/health
```

---

## Android Emulator Setup

For Android emulator, use:

```env
AI_BACKEND_BASE_URL=http://10.0.2.2:8000
```

---

## Flutter App

```powershell
cd app
flutter clean
flutter pub get
flutter run
```

Analyze Flutter code:

```powershell
flutter analyze
```

---

## 🧪 Testing

### Backend Compile Check

```powershell
python -m compileall backend
```

### Run Backend

```powershell
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

### Run Flutter

```powershell
cd app
flutter clean
flutter pub get
flutter analyze
flutter run
```

---

## 📊 Evaluation

The project includes recommendation evaluation support.

Implemented metrics:

* Precision@K
* Recall@K
* nDCG@K
* MRR

Run evaluation:

```powershell
python -m evaluation.benchmark
```

Example evaluation table format:

```text
Scenario                  Precision@5   Recall@5   nDCG@5
Trekking + Adventure       0.80          0.67       0.86
Culture + Peaceful         0.75          0.60       0.81
Family + Budget            0.70          0.58       0.78
```

---

## 🎓 Demo Explanation

This project is not a basic filter-based tourism app.

A basic system would only match exact fields like:

```text
activity == trekking
budget == medium
season == autumn
```

This system is more advanced because it uses a hybrid AI pipeline:

```text
SBERT semantic matching
+ collaborative filtering
+ popularity fallback
+ contextual reranking
+ offline local recommendation
+ cached AI fallback
+ explainable scoring
```

For new users, the system uses semantic and popularity-based signals.
For returning users, it uses interaction history to personalize results.
When the backend is unavailable, the app still provides offline recommendations.

---

## ⚠️ Limitations

* Dataset size is limited
* JSON storage is not ideal for large-scale production
* Collaborative filtering improves only after enough interaction data exists
* Backend must be running for full AI online mode
* Local IP changes when Wi-Fi network changes

---

## 🔮 Future Improvements

Production-level improvements:

* Replace JSON storage with PostgreSQL
* Add user authentication
* Add real-time interaction tracking
* Add offline interaction sync
* Deploy FastAPI backend online
* Add Redis caching
* Add Docker support
* Add CI/CD pipeline
* Add model/version tracking
* Improve learning-to-rank model

---

## 🏁 Current Status

The current version supports:

```text
Online AI recommendation
Offline recommendation
Cold-start handling
Cached AI fallback
Local user personalization
Explainable recommendation reasons
Evaluation metrics
```

This makes the project suitable for an advanced college AI/ML demonstration.

---

## 👨‍💻 Author

Abhiii10

---

## 📜 License

This project is developed for academic purposes.

````

