# Nepal Tourism Recommendation App - Startup Audit

Audit date: 2026-05-21

This app is not a bad academic prototype. It already has a hybrid recommender, offline data assets, chatbot, translation, local SQLite storage, and a FastAPI backend. The problem is that the product still exposes prototype decisions in places real travelers will immediately feel: map quality, offline confidence, language UX, visual consistency, state ownership, and reliability under poor networks.

## What I Improved In Code

| Area | Change | Why It Matters | Production-Level Impact |
| --- | --- | --- | --- |
| App shell | Added `darkTheme` and `ThemeMode.system` | Dark mode was requested but the app only registered a light theme. | The app now respects OS theme and has a real dark baseline. |
| Startup load | Loaded destinations, stays, similarity data, and saved places in parallel | Sequential asset/database loading makes startup feel slower for no reason. | Faster first usable screen without changing architecture. |
| Bottom navigation | Made nav colors theme-aware and accessible through `Semantics` | Hardcoded white/gray nav breaks dark mode and accessibility. | Better contrast, screen-reader labels, and safer scaling. |
| Recommendation cache | Moved AI recommendation cache from `SharedPreferences` to SQLite | `SharedPreferences` is weak for larger structured payloads and cache expiry logic. | More scalable offline fallback path for real users. |
| Cache correctness | Included family/adventure/topK in the AI cache key | Old cache could show stale/wrong results for different traveler profiles. | Recommendations now match the actual preference profile. |
| API resilience | Added retry for transient backend failures and a 3-second health check timeout | A 20-second health probe makes the recommender feel broken in poor networks. | Faster fallback to offline mode in Nepal connectivity conditions. |
| Map UX | Reworked the map screen with themed markers, zoom controls, average centering, and a destination preview card | The old map was a raw pin dump with red markers and no preview interaction. | Feels closer to a real travel app while staying on `flutter_map`. |
| Chat intent quality | Fixed monsoon/homestay classification | Tests passed before, but logs showed real user questions being misread. | Chatbot intent test now reaches 30/30. |
| Web/desktop storage | Added web fallback storage and desktop SQLite factory configuration | The web target crashed before rendering because `sqflite` was initialized like a mobile-only database. | Web smoke test now renders the app and the map; desktop builds get the correct FFI database factory. |
| Offline maps | Added MBTiles provider wiring, bundled asset registration, and safe mobile/desktop fallback | The map layer was online-only and the bundled `pokhara.mbtiles` placeholder was not usable. | Mobile/desktop are ready to render a real MBTiles export when supplied; web safely falls back to online tiles because MBTiles SQLite is not supported there. |
| App foundations | Added Riverpod provider scope and catalog/telemetry providers | The app needs shared state boundaries before it grows further. | Data, telemetry, and future feature state now have a scalable provider entry point. |
| Localization | Added Flutter `gen-l10n` ARB files for English and Nepali | Translation utility is not the same thing as localized UI. | The app has a real localization pipeline ready for screen-by-screen string migration. |
| Observability | Added optional Sentry and PostHog integration through env vars | Real startup apps need crash and product signals. | Local dev stays free/disabled; production can enable telemetry without code changes. |
| Backend persistence | Added SQLite interaction repository with JSON seeding and backend selection | JSON writes are risky under real concurrent usage. | Interactions now default to SQLite while keeping JSON as a compatibility fallback. |
| Image pipeline | Added a compressed WebP hero asset and optimization script | A 2.9 MB hero image is too heavy for low-end phones. | Home loads a 170 KB WebP hero instead of the original PNG. |

## Known Launch Blocker

`app/assets/maps/pokhara.mbtiles` is currently a zero-byte placeholder. The app now detects invalid MBTiles files and falls back to online tiles instead of crashing, but a real offline Pokhara/Kathmandu/Nepal MBTiles export is still required before advertising true offline base maps.

## Brutally Honest Product Diagnosis

| Area | Current Weakness | Why It Matters | How To Fix | Production-Level Definition |
| --- | --- | --- | --- | --- |
| Home | The hero is pleasant but generic; it does not immediately answer "where should I go today?" | Gen Z users expect instant utility, not just brochure energy. | Add personalized chips: "2-day escape", "under NPR 5k", "safe in monsoon", "near Pokhara", "offline-ready". | First screen should convert a confused traveler into one clear next action. |
| Recommendations | The controls are engineer-centric: activity, budget, season, vibe. Useful, but not emotionally natural. | Travelers think in constraints and moods, not model dimensions. | Keep the model inputs internally, but expose prompts like "I have 1 day", "traveling with family", "avoid difficult roads", "want quiet villages". | The UI maps human intent into model features invisibly. |
| Recommendation quality | Offline TF-IDF is useful, but still shallow compared with itinerary context, road risk, weather, distance, and traveler constraints. | Nepal tourism decisions are highly situational. A technically good semantic match can still be a bad trip. | Add scoring signals for travel time from current hub, road seasonality, altitude, current month, permit needs, local stay availability, and confidence level. | Recommendations should be explainable and operationally safe, not just similar. |
| Map | The app had no real offline map path; the bundled `assets/maps/pokhara.mbtiles` file is only a placeholder. | This directly violates offline-first expectations. | Keep the new MBTiles provider, replace the placeholder with a real export, then use online tiles only as fallback. | A tourist can open saved areas with airplane mode on. |
| Offline | Saved destinations exist, but there is no real offline trip pack concept. | Poor internet is not an edge case in rural Nepal; it is the default risk. | Add "Save trip pack" containing destination, map tiles/MBTiles area, phrasebook entries, emergency contacts, route notes, stays, and cached recommendations. | Offline is a planned mode, not a fallback message. |
| Translation | The phrasebook/intent model is strong for zero cost, but online Google Translate uses an unofficial endpoint. | It can break or rate-limit without warning. | Make phrasebook-first UX explicit, cache every successful online translation, add user correction, and migrate UI localization to Flutter ARB files. | Core survival phrases work offline; app UI language is localized independently from translator logic. |
| Chatbot | The chatbot has useful local knowledge but risks sounding like a static FAQ. | Users compare chat to modern AI assistants, even if your app is offline. | Keep local deterministic intents for offline; when online, enrich with backend/RAG context from current destination and saved trip. | Online chat feels contextual; offline chat remains reliable. |
| Architecture | Stateful widgets own too much app behavior. | `setState` is fine locally but does not scale across saved state, user profile, network status, cache, and language. | Move app-level state to Riverpod: providers for destinations, saved places, recommendation state, map selection, translation history, network/backend status. | UI becomes a thin render layer; async loading/error states are consistent. |
| Persistence | Raw `sqflite` is okay, but repository boundaries are inconsistent. | As data grows, migrations and typed queries become painful. | Either tighten current repositories or migrate to Drift for typed SQLite, migrations, streams, and testable DAOs. | Offline data has schema ownership, migrations, and reactive updates. |
| Backend | JSON repositories are risky for concurrent writes and real users. | Interaction logging and recommendation feedback will corrupt or bottleneck under production traffic. | Use SQLite/Postgres for backend interactions; keep JSON only as seed data. Add request IDs and structured logging. | Backend can handle multiple users without data-loss anxiety. |
| Observability | No analytics/crash reporting path is wired. | You cannot improve recommendations if you cannot see failed searches, offline usage, crashes, or abandoned flows. | Use PostHog for product events and Sentry for crash/performance tracking. Keep events privacy-safe. | Every major user action has a measured funnel and error context. |
| Accessibility | Some UI is pretty but dense, with many custom chips/cards and hardcoded colors. | Premium does not mean inaccessible. | Add semantic labels, contrast checks, scalable text QA, tap targets >= 44 px, and reduced-motion handling. | Usable by tourists outdoors, tired, moving, and on low-end phones. |

## Screen-By-Screen UX Direction

### Home

- Why: Home should be a decision engine, not a content catalog.
- How: Add intent-first entry cards: "Weekend from Pokhara", "Village homestays", "Monsoon-safe", "Low budget", "Easy road access", "Best views now".
- Production-level: Rank these cards by season, saved behavior, and offline availability.

### Discover / Recommendations

- Why: The model is strong, but the UI exposes model knobs too directly.
- How: Keep advanced controls but lead with traveler scenarios. Use progressive disclosure for score breakdowns.
- Production-level: Every result explains "why this, why now, what to watch out for, what to do next".

### Map

- Why: A tourism app without a great map feels unfinished.
- How: Add offline MBTiles, category filters, selected-place preview, clustering for dense data, saved pins, and route/time metadata.
- Production-level: Map remains usable offline, avoids tile-server abuse, and clearly distinguishes cached vs online tiles.

### Saved

- Why: Saved places are not enough; travelers need plans.
- How: Convert saved into "Trips" with days, notes, budget, emergency info, and offline pack status.
- Production-level: Saved content syncs or exports later, but works fully offline first.

### Translation

- Why: Translation is a true Nepal-specific differentiator.
- How: Add big emergency/transport/food phrase cards, language toggle persistence, correction feedback, transliteration help, and cached online results.
- Production-level: Zero-network survival UX with graceful online enhancement.

### Chat

- Why: The chatbot can become the app's concierge if it knows current context.
- How: Add context chips from current destination/saved trip and route answers through deterministic offline intents first.
- Production-level: It never hallucinates critical safety details; it says when confidence is low.

### Detail Pages

- Why: Detail pages should close the travel decision.
- How: Add "Best for", "Avoid if", "How to reach", "Typical cost", "Stay options", "Offline saved", "Nearby", and "Safety/season notes".
- Production-level: A user can decide, save, navigate, and prepare from one screen.

## Practical Feature Priorities

| Priority | Feature | Why | How |
| --- | --- | --- | --- |
| P0 | Offline trip packs | Most Nepal travelers will hit weak connectivity. | SQLite metadata + MBTiles + cached destination/stay/translation data. |
| P0 | Real map offline support | The code path is wired, but the checked-in MBTiles file is a placeholder. | Replace `app/assets/maps/pokhara.mbtiles` with a valid MBTiles export and keep online fallback only when needed. |
| P0 | Recommendation confidence and constraints | Safety and travel feasibility matter more than novelty. | Add confidence labels and constraint warnings into scoring and UI. |
| P1 | Scenario-based onboarding | Cold start needs fast personalization. | Ask trip length, hub city, budget, group type, transport comfort, language. |
| P1 | Itinerary builder | Saves become trips, not bookmarks. | Drag destinations into day cards, store locally, export/share later. |
| P1 | Analytics events | You need to know what users actually search and abandon. | Track privacy-safe events: search, recommend, save, offline pack, translation, map open. |
| P2 | Backend DB | JSON backend storage will not survive real use. | SQLite for demo deployment, Postgres/Supabase later. |
| P2 | Image pipeline | Cards rely heavily on icons/gradients instead of real place imagery. | Add compressed WebP assets, placeholders, and lazy loading. |

## Recommended Near-Zero-Cost Tooling

- State management: Riverpod, because it handles async loading/error states cleanly and gives better tooling for app-wide state.
- Offline persistence: keep `sqflite` short term; consider Drift when schema and migrations grow.
- Maps: keep `flutter_map`; add MBTiles support with an MIT provider or use built-in caching/asset tiles depending on licensing and bundle size.
- Analytics: PostHog Flutter SDK for open-source product analytics or self-hosting later.
- Crash/performance: Sentry Flutter SDK on free tier for crash and performance visibility.
- Localization: Flutter `gen-l10n` with ARB files for UI strings; keep the phrasebook/intent translator as a separate travel utility.

## Architecture Direction

Target structure:

```text
lib/
  app/                 # app shell, routing, theme, bootstrap
  features/
    home/
    recommendations/
    map/
    saved_trips/
    translation/
    chat/
  core/
    network/
    storage/
    analytics/
    localization/
    design_system/
  data/
    local/
    remote/
    repositories/
  domain/
    entities/
    use_cases/
```

Why this matters: your current `screens/` and `services/` layout is understandable now, but it will become a junk drawer as soon as map packs, trips, onboarding, analytics, and sync arrive.

Production-level implementation:

- Feature folders own their UI, state, and small models.
- `core/storage` owns SQLite/Drift and migrations.
- `core/network` owns retries, request IDs, DTO parsing, and backend availability.
- Repositories hide data source decisions.
- UI consumes providers/use cases, not raw singleton services.

## References Checked

- Flutter map offline options: https://docs.fleaflet.dev/tile-servers/offline-mapping
- MBTiles provider: https://pub.dev/packages/flutter_map_mbtiles/versions
- Riverpod async state/tooling: https://riverpod.dev/
- Drift persistence/migrations: https://drift.simonbinder.eu/faq/
- Flutter performance guidance: https://docs.flutter.dev/perf
- Flutter internationalization/gen-l10n: https://docs.flutter.dev/ui/internationalization
- Sentry Flutter crash/performance: https://docs.sentry.io/platforms/flutter/
- PostHog Flutter package: https://pub.dev/packages/posthog_flutter
