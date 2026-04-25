# 🇳🇵 Nepal Rural Tourism Recommendation System

## 📌 Overview

This project is an **AI-powered tourism recommendation system** designed to promote rural destinations in Nepal.
It combines **semantic search, collaborative filtering, and contextual reranking** to deliver personalized travel suggestions.

---

## 🧠 System Architecture

```
User Input (preferences)
        ↓
Candidate Retrieval (SBERT semantic search)
        ↓
Collaborative Filtering (user interaction patterns)
        ↓
Contextual Reranking (budget, season, vibe, etc.)
        ↓
Final Recommendations + Explanation
```

---

## ⚙️ Tech Stack

### Backend

* Python
* FastAPI
* Sentence Transformers (SBERT)
* Scikit-learn
* JSON-based storage

### Frontend

* Flutter (Dart)
* Offline-first architecture
* REST API integration

---

## 🚀 Features

* 🔍 Semantic destination search (SBERT)
* 🤝 Collaborative filtering based on user interactions
* 🎯 Context-aware recommendations (budget, season, vibe)
* 📱 Offline + online hybrid mobile app
* 🗺️ Map-based exploration
* 🧾 Explainable recommendations

---

## 📂 Project Structure

```
app/        → Flutter mobile application
backend/    → FastAPI recommendation engine
data/       → JSON datasets
evaluation/ → Metrics & benchmarking
scripts/    → Utility scripts
```

---

## ▶️ How to Run

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install -r ../requirements.txt
uvicorn backend.main:app --reload
```

API Docs:

```
http://127.0.0.1:8000/docs
```

---

### Frontend (Flutter)

```bash
cd app
flutter pub get
flutter run
```

---

## 📊 Recommendation Approach

### 1. Semantic Retrieval

* Uses SBERT embeddings to match user preferences with destinations.

### 2. Collaborative Filtering

* Learns from user interaction history.

### 3. Contextual Reranking

Final score:

```
score = (semantic × 0.50) + (collaborative × 0.20) + (contextual × 0.30)
```

---

## 📈 Evaluation

Metrics implemented:

* Precision@K
* Recall@K
* nDCG@K

Run evaluation:

```bash
python evaluation/benchmark.py
```

---

## ⚠️ Limitations

* Cold-start problem for new users
* Limited dataset size
* No real-time user tracking

---

## 🔮 Future Improvements

* Add real-time user feedback loop
* Deploy backend (Render / AWS)
* Replace JSON storage with database
* Improve recommendation explainability

---

## 👨‍💻 Author

Abhiii10

---

## 📜 License

This project is for academic purposes.
