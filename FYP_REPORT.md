# Paila Nepal: An Offline-First Rural Tourism Mobile Application for Gandaki Province

**Final Year Project Technical Report**

**Student:** [Student Name]  
**Roll No:** [Roll No]  
**Department:** [Department]  
**Institution:** [University Name]  
**Academic Year:** 2025/2026  
**Application Name:** Paila Nepal  
**Package Name:** `com.example.rural_tourism_app`  
**Platform:** Android  
**Technology Stack:** Flutter, Dart, FastAPI, SQLite, MBTiles, OpenStreetMap, OSRM

**Page i**

---

## Abstract

Paila Nepal is an offline-first rural tourism mobile application designed for travelers exploring Gandaki Province, Nepal, especially Pokhara and surrounding rural destinations where mobile connectivity is often unreliable. The application addresses a practical gap in existing tourism platforms: most popular map and travel applications depend heavily on continuous internet access and are optimized for well-known urban or commercial destinations. In contrast, rural tourism requires resilient access to destination information, local map tiles, saved places, route guidance, safety information, and contextual recommendations even when the user is outside network coverage.

The project implements a Flutter-based Android application supported by a FastAPI backend. The mobile app stores 300 curated Gandaki Province destinations, 300 local WebP destination photographs, JSON knowledge assets, SQLite databases, SharedPreferences settings, and a raster PNG MBTiles map package for offline map display. Routing is implemented using a three-tier strategy: a 30-day SQLite route cache, online OSRM routing when connectivity is available, and a Haversine straight-line fallback with travel-mode speed estimates when offline. The chatbot combines local knowledge-base retrieval, keyword-based intent classification, emergency detection, and optional online language-model enhancement. The recommendation module uses destination attributes and user preferences to provide personalized suggestions while preserving offline usability.

Testing shows that the app can launch offline, load all 300 destinations, display local map tiles, answer tourism questions through local NLP, show saved destinations from SQLite, and provide approximate offline routes without unhandled exceptions. The final APK remains practical for distribution by bundling only Gandaki-focused map tiles and optimized local images. Overall, Paila Nepal demonstrates how offline-first mobile architecture can make rural tourism information more reliable, accessible, and locally relevant.

**Keywords:** rural tourism, Flutter, offline-first, Gandaki Province, MBTiles, OSRM, SQLite, recommendation system, chatbot, OpenStreetMap.

**Page ii**

---

## Table of Contents

- Abstract
- Chapter 1: Introduction
  - 1.1 Background and Motivation
  - 1.2 Problem Statement
  - 1.3 Objectives
  - 1.4 Scope and Limitations
  - 1.5 Report Organization
- Chapter 2: Literature Review
  - 2.1 Rural Tourism in Nepal
  - 2.2 Offline-First Mobile Applications
  - 2.3 Recommendation Systems
  - 2.4 Natural Language Processing for Chatbots
  - 2.5 Related Work
- Chapter 3: System Design and Architecture
  - 3.1 System Architecture Overview
  - 3.2 Feature Architecture
  - 3.3 Offline Architecture
  - 3.4 Data Architecture
  - 3.5 State Management
  - 3.6 Database Schema
- Chapter 4: Implementation
  - 4.1 Technology Stack
  - 4.2 Offline Map Implementation
  - 4.3 Routing Service Implementation
  - 4.4 Chatbot Implementation
  - 4.5 Recommendation System
  - 4.6 Destination Data
  - 4.7 Key Screens
- Chapter 5: Testing and Results
  - 5.1 Testing Strategy
  - 5.2 Offline Functionality Testing
  - 5.3 Performance Results
  - 5.4 APK Size Analysis
- Chapter 6: Challenges and Solutions
  - 6.1 Offline Map Tile Format
  - 6.2 MBTiles TMS vs XYZ Coordinate System
  - 6.3 Large File Size
  - 6.4 Offline Routing
  - 6.5 Vector vs Raster Tiles
- Chapter 7: Conclusion and Future Work
  - 7.1 Summary of Achievements
  - 7.2 Future Work
  - 7.3 Final Remarks
- References

**Page iii**

---

# Chapter 1: Introduction

**Page 1**

## 1.1 Background and Motivation

Tourism is one of Nepal's most important economic and cultural sectors. The country is internationally recognized for mountains, trekking routes, pilgrimage sites, lakes, protected landscapes, cultural settlements, and diverse ethnic traditions. Within Nepal, Gandaki Province has a particularly strong tourism identity because it includes Pokhara, Annapurna-region villages, lakeside destinations, Gurung and Magar settlements, rural homestay areas, viewpoints, religious sites, and trekking corridors. However, the digital infrastructure supporting rural tourism remains uneven. Travelers frequently depend on large global applications such as Google Maps, TripAdvisor, commercial booking tools, or social media posts. These tools are useful in well-connected urban areas but become less reliable in mountainous terrain and remote settlements.

The motivation for Paila Nepal comes from the gap between the tourism potential of rural Gandaki Province and the practical limitations faced by visitors. A tourist moving from Pokhara to a rural village may lose mobile data, experience weak GPS-assisted map loading, or fail to access online destination descriptions. Even when a destination is known locally, information may be fragmented across blogs, map listings, transport discussions, and informal recommendations. In rural tourism, timely access to basic information matters: travelers need to know where a place is, what activities it offers, whether it is suitable for families, what budget level to expect, what season is appropriate, and how to navigate toward it.

Most tourism applications are designed with the assumption that internet connectivity is continuously available. This assumption is problematic in Gandaki Province because many rural destinations are located in hills, valleys, trekking routes, and settlements where mobile data is unstable. Online-only applications fail in precisely the moments when travelers most need help: checking directions on a rural road, identifying nearby attractions, reading safety guidance, or asking basic questions about transport and accommodation. For rural travelers, a dependable local-first application is not merely a convenience. It is part of travel safety, confidence, and accessibility.

Paila Nepal is designed as an offline-first rural tourism guide. The phrase "offline-first" means that the application treats local data as the primary source of truth and uses the network only as an enhancement when available. Instead of loading destinations from the internet every time, it bundles a curated Gandaki dataset inside the application. Instead of depending entirely on live map tiles, it includes a local MBTiles map package. Instead of requiring cloud AI for every chatbot response, it includes an offline knowledge base and local natural-language processing. Instead of failing when OSRM routing is unreachable, it falls back to cached routes or approximate Haversine-based routes.

The app name "Paila Nepal" reflects the idea of a step or journey. The application supports travelers as they take their next step into rural Nepal with information that remains accessible even outside network coverage. This project therefore combines mobile development, geographic information systems, recommendation systems, local storage, offline map rendering, natural-language processing, and backend integration into one complete tourism application.

## 1.2 Problem Statement

Rural travelers in Gandaki Province face three related digital problems. First, they lose access to maps and navigation when internet connectivity drops. Online map applications generally cache some data temporarily, but they are not designed around a locally bundled rural destination dataset with guaranteed offline availability. When network access is lost, map tiles may stop loading, route requests may fail, and destination markers may not appear.

Second, travelers lose access to contextual tourism information. Many rural destinations do not have rich, structured, locally relevant information in global travel platforms. A user may find the name of a place but not the activities, accessibility level, budget expectations, seasonal suitability, cultural context, family-friendliness, or nearby accommodation options. This creates an information gap for both domestic and international travelers.

Third, existing tourism applications are usually not dedicated to Gandaki Province's rural tourism context. They are often general-purpose tools, booking platforms, review sites, or city-focused travel guides. They may not emphasize small villages, viewpoints, homestay settlements, trekking-adjacent sites, local culture, or offline safety. As a result, rural destinations remain digitally underrepresented even when they are valuable for local tourism development.

The central problem addressed by this project is therefore:

**How can a mobile application provide destination discovery, offline map access, route guidance, chatbot assistance, saved places, and personalized recommendations for Gandaki Province rural tourism even when internet connectivity is unavailable?**

This problem requires more than simply storing static text. It requires a complete offline-capable system: local destination data, local media assets, local map tiles, route caching, fallback route computation, local search and filtering, local chatbot response generation, local saved-place storage, and online enhancement only when available.

## 1.3 Objectives

The main objective of Paila Nepal is to design and implement a Flutter-based Android application that supports offline-first rural tourism exploration in Gandaki Province. The specific objectives are:

1. To build a fully offline-capable Flutter mobile application for Android that can launch, display destination data, support map exploration, and answer basic tourism queries without requiring internet connectivity.

2. To provide a curated dataset of 300 rural tourism destinations in Gandaki Province, including destination names, descriptions, coordinates, categories, activities, best seasons, budget levels, accessibility attributes, family-friendliness indicators, adventure levels, cultural richness scores, nature scores, tags, and image metadata.

3. To bundle local destination photos for all 300 destinations using optimized WebP images so that destination cards and details screens remain visually useful offline.

4. To implement offline map display using a local MBTiles raster map package focused on Pokhara and surrounding Gandaki Province areas, with fallback to online CartoDB or OpenStreetMap tiles when local tiles are unavailable.

5. To implement route guidance using a three-tier routing architecture consisting of SQLite route cache, online OSRM route retrieval, and offline Haversine straight-line fallback with travel-mode duration estimates.

6. To implement an offline chatbot that uses local tourism knowledge, keyword-based intent classification, emergency detection, and structured responses without depending on cloud AI.

7. To provide personalized recommendations based on user preferences such as category, budget, adventure level, family suitability, activities, season, and destination attributes.

8. To support saved destinations, recommendation caching, user preferences, and app settings through local SQLite and SharedPreferences storage.

9. To integrate a FastAPI backend for online enhancements such as AI responses, recommendation synchronization, destination image lookups, and analytics, while preserving mobile functionality when the backend is unreachable.

10. To evaluate the application through unit tests, integration checks, offline functionality tests, performance observations, and APK size analysis.

## 1.4 Scope and Limitations

The scope of this project is intentionally focused. The application covers Gandaki Province, Nepal, with particular attention to Pokhara and surrounding rural destinations. The current destination dataset includes 300 curated entries. The offline map package is limited to a Gandaki-focused area and includes raster PNG MBTiles at zoom levels 7 to 12. This zoom range is suitable for regional exploration and rural destination browsing, but it does not provide full street-level detail for every village.

The routing module uses OSRM online routing when internet access is available. OSRM provides real road-network routes and turn-by-turn steps through an HTTP API. However, fully offline turn-by-turn routing would require bundling and querying a local road graph, which is beyond the current scope. When offline and no cached route is available, the app provides an approximate straight-line route using the Haversine formula. This fallback is useful for direction and distance estimation but is not a substitute for road-aware navigation.

The chatbot works offline using a local knowledge base, intent classification, and rule-based response logic. It does not run a large language model locally on the mobile device. When backend and API keys are configured, online LLM responses can enhance the chatbot. Offline mode remains available, but it is limited to the local knowledge and predefined reasoning logic.

The project targets Android only. Although Flutter supports cross-platform development, iOS support was not included because the development, testing, and packaging workflow focused on Android devices and emulators. The backend uses FastAPI and Docker for local or production-style deployment, but the core offline mobile application can operate independently once installed with bundled assets.

Other limitations include the possibility that some destination images are best-available Wikimedia or regional photographs rather than exact photographs of obscure places; limited offline map zoom; limited real-time traffic awareness; no community review submission in the current version; and no fully self-hosted offline routing engine.

## 1.5 Report Organization

This report is organized into seven chapters. Chapter 1 introduces the project background, problem statement, objectives, scope, and limitations. Chapter 2 reviews literature and related technologies, including rural tourism in Nepal, offline-first mobile application patterns, recommendation systems, local NLP chatbots, and related tourism applications. Chapter 3 presents the system design and architecture, including layered architecture, feature organization, offline strategy, data architecture, state management, and database schema. Chapter 4 describes the implementation of major modules such as maps, routing, chatbot, recommendation engine, destination data, and key screens. Chapter 5 presents testing strategy, offline functionality testing, performance observations, and APK size analysis. Chapter 6 discusses major challenges and their solutions, particularly map tile format, coordinate systems, file size, offline routing, and raster tile generation. Chapter 7 concludes the report with achievements, future work, and final remarks. The report ends with references to official documentation and academic literature.

---

# Chapter 2: Literature Review

**Page 7**

## 2.1 Rural Tourism in Nepal

Rural tourism in Nepal is closely connected to natural landscapes, cultural heritage, mountain settlements, local hospitality, religious practices, and community-based economic development. Unlike mass tourism concentrated in major urban centers or internationally famous trekking routes, rural tourism encourages visitors to explore villages, local food, traditional homes, agricultural landscapes, viewpoints, monasteries, temples, lakes, rivers, forests, and homestays. This form of tourism can distribute economic benefits beyond large hotels and commercial tourism operators.

Gandaki Province is particularly significant because it includes Pokhara, one of Nepal's major tourism gateways, and many surrounding rural destinations. Pokhara acts as a starting point for trekking, paragliding, lake tourism, religious visits, mountain views, and rural village trips. Nearby destinations such as Ghandruk, Ghorepani, Bandipur, Begnas, Sikles, and many lesser-known settlements illustrate the diversity of tourism opportunities in the province. Academic work on Gandaki tourism has examined resident perceptions, tourism impacts, homestay potential, and socio-economic transformation. Such studies show that tourism is not only an entertainment industry but also a social and development activity that affects livelihoods, community identity, infrastructure, and cultural exchange.

However, rural tourism depends heavily on information accessibility. A traveler is more likely to visit a rural destination when information about access, accommodation, safety, season, activities, and local culture is clear. Many rural destinations are not represented adequately in mainstream commercial platforms. Even when they appear on maps, their descriptions may be incomplete, photos may be missing, and route guidance may depend on internet connectivity. The digital gap is therefore a barrier to rural tourism development.

The Paila Nepal project responds to this gap by treating rural destination information as core local data, not optional online content. It stores destinations inside the app, provides structured attributes for recommendation, and includes local photographs. This approach aligns with the needs of rural tourism because it values small destinations and preserves access to information in low-connectivity contexts.

## 2.2 Offline-First Mobile Applications

Offline-first architecture is a design approach in which an application remains useful even without network connectivity. Rather than treating offline mode as an error state, offline-first systems treat local data as a primary operational layer. The network becomes an enhancement channel for synchronization, updates, remote computation, or improved results. Modern mobile architecture guidance emphasizes that offline-first apps should read from local sources, queue or cache operations when needed, and reconcile with network sources when connectivity returns.

This architecture is well suited to rural tourism applications because users may move through locations where connectivity changes frequently. A network-first app can fail unpredictably, while an offline-first app can provide stable core behavior. For Paila Nepal, offline-first architecture appears in several areas:

- Destination records are bundled in JSON assets.
- Destination images are bundled as local WebP assets.
- Map tiles are stored as local MBTiles.
- Saved destinations are stored in SQLite.
- Recommendations are cached locally.
- Route results are cached in SQLite for 30 days.
- Offline routing fallback uses local computation.
- Chatbot responses use local knowledge and NLP.
- User preferences are stored in SharedPreferences.

Flutter is an appropriate framework for this design because it supports high-performance custom UI, local asset bundling, plugin-based native integration, and cross-platform development. Although this project targets Android, Flutter's architecture still provides benefits through declarative widgets, consistent rendering, and access to packages for SQLite, maps, location, connectivity, HTTP, local preferences, and cached images.

MBTiles is a key offline map technology. The MBTiles specification defines a SQLite-based container for tiled map data. Because a single `.mbtiles` file can store thousands of map tiles, it is easier to bundle, validate, and distribute than loose tile files. In Paila Nepal, MBTiles is used to store raster PNG tiles for Gandaki Province. This allows the Flutter map to display regional tiles without downloading them at runtime.

## 2.3 Recommendation Systems

Recommendation systems help users discover relevant items from a large collection. In tourism, recommender systems can suggest destinations, activities, points of interest, routes, accommodations, or trip plans based on user preferences and contextual factors. Tourism recommendation is more complex than recommending simple products because travel decisions involve distance, season, budget, activity type, safety, cultural interest, family needs, weather, accessibility, and personal mood.

Content-based filtering recommends items by comparing item attributes with user preferences. For example, if a user prefers trekking, nature, budget-friendly places, and moderate adventure, the system can score destinations with matching categories and attributes. This approach is useful for cold-start situations where user interaction history is limited, which is common in a newly installed tourism app.

Hybrid recommendation systems combine multiple signals. These can include content-based scores, collaborative behavior, popularity, contextual reranking, and diversity constraints. In Paila Nepal, the recommendation approach is primarily content-based on the mobile app, with backend support for more advanced hybrid scoring. Destination attributes such as category, activities, season, budget level, accessibility, family-friendliness, adventure level, culture level, nature level, tags, and descriptions provide a rich basis for matching.

Tourism recommendation literature emphasizes the importance of personalization and context. A destination that is ideal for a solo trekker may not be suitable for a family with children. A place that is attractive in autumn may be unsafe or inaccessible during monsoon. Paila Nepal models this by including structured fields such as best season, budget level, accessibility, adventure level, and family-friendly status. The result is a practical recommendation system aligned with rural travel decisions.

## 2.4 Natural Language Processing for Chatbots

Chatbots in tourism applications can help users ask natural questions such as "What is the best time to visit Ghandruk?", "Is trekking safe during monsoon?", "How much budget do I need?", or "What should I do in an emergency?" Cloud-based large language models can produce fluent responses, but they require internet connectivity and API keys. In an offline-first rural tourism app, relying entirely on cloud AI would reproduce the same connectivity problem that the project is trying to solve.

Local NLP provides a practical alternative. A local chatbot can use keyword matching, intent classification, knowledge-base retrieval, templates, and safety rules. It may not be as flexible as a large cloud model, but it can answer common tourism questions reliably and quickly. The main design goal is not to imitate human-level conversation but to provide useful, safe, and contextually relevant information under offline constraints.

Paila Nepal's chatbot uses a knowledge base stored in app assets. It classifies intents by matching user input against keyword sets and example phrases. It also includes emergency detection for safety-critical queries. Emergency detection is important because the app may be used in unfamiliar rural environments. If the user asks about injury, police, ambulance, getting lost, landslides, or urgent help, the system can prioritize direct safety information.

The app also contains an online enhancement path. When backend services and API keys are configured, the chatbot can use online LLM responses. However, the offline chatbot remains the dependable base layer. This design follows the offline-first principle: cloud AI improves the experience when available but is not required for core operation.

## 2.5 Related Work

Several existing applications are relevant to this project. Google Maps provides extensive map coverage, search, and navigation. However, its strongest features depend on internet connectivity, account services, live routing, and online map data. Users can download offline areas manually, but Google Maps is not designed as a dedicated rural tourism guide with curated Gandaki destinations, local chatbot knowledge, and tourism-specific recommendations.

TripAdvisor provides reviews, rankings, hotel information, restaurants, and tourism content. It is valuable for popular destinations but is primarily online and commercially oriented. It does not provide a Gandaki-specific offline map package or local route fallback for remote areas.

OSMAnd is a powerful offline map application based on OpenStreetMap data. It provides offline maps and navigation features. However, it is a general mapping tool, not a curated rural tourism application. It does not focus on Gandaki Province destination discovery, tourism categories, local recommendations, destination photographs, chatbot assistance, or app-specific rural travel content.

Other booking and travel applications usually focus on accommodations, commercial attractions, reviews, or itinerary planning. They are useful in connected environments but do not address the specific combination required here: offline destination data, offline map display, offline route fallback, local chatbot, personalization, and rural tourism context.

The gap filled by Paila Nepal is therefore the integration of tourism-specific content and offline-first engineering. It combines local Gandaki destination knowledge with maps, routing, chatbot support, saved places, and recommendation logic in one Android application.

[DIAGRAM: Related work comparison diagram showing Google Maps, TripAdvisor, OSMAnd, and Paila Nepal along two axes: offline capability and rural tourism specialization. Paila Nepal occupies the quadrant with high offline capability and high rural tourism specialization.]

---

# Chapter 3: System Design and Architecture

**Page 13**

## 3.1 System Architecture Overview

Paila Nepal follows a layered architecture that separates presentation, domain, data, and core services. This separation improves maintainability and allows offline and online behavior to be managed cleanly.

The presentation layer consists of Flutter widgets, screens, UI components, bottom sheets, cards, map overlays, forms, and navigation. It is responsible for rendering destination lists, map markers, route lines, chatbot messages, saved places, user preferences, and account screens. The presentation layer reacts to state changes through Riverpod providers, local state, controllers, and service calls.

The domain layer contains entities and models that represent the main concepts of the app. Examples include `Destination`, `UserProfile`, `RouteResult`, `RouteStep`, recommendation results, chat messages, and authentication models. These models define the structure of data independently of UI rendering. They allow data to move between services and screens in a type-safe manner.

The data layer manages persistence and asset loading. `LocalDataService` reads and writes local SQLite data such as saved destinations and recommendation cache. Asset JSON files provide destination records, chatbot knowledge, phrasebook data, embeddings, and configuration. SharedPreferences stores lightweight user preferences and settings. RouteCache stores route results in a separate SQLite database.

The core services layer contains cross-cutting logic. `RoutingService` handles route retrieval, OSRM calls, cache checks, and fallback routing. `RouteCache` handles cached route storage and expiry. `OfflineTileProvider` handles MBTiles validation and loading. `ChatbotService` handles local chatbot responses. `WikiImageService` and local image services handle destination images. Connectivity and backend configuration utilities determine whether online features should be used.

[DIAGRAM: Layered architecture diagram with four horizontal layers. Top: Presentation Layer with Flutter screens and widgets. Second: Domain Layer with Destination, UserProfile, RouteResult, and ChatMessage entities. Third: Data Layer with LocalDataService, SQLite, SharedPreferences, JSON assets, and image assets. Bottom: Core Services with RoutingService, ChatbotService, OfflineTileProvider, RouteCache, BackendConfig, and FastAPI integration.]

This architecture supports offline-first behavior because most presentation features depend on local services first. The backend improves the experience but does not become a single point of failure for core functionality.

## 3.2 Feature Architecture

The Flutter app is organized into feature folders. This improves modularity by grouping related screens, models, services, and widgets.

`/features/destinations/` contains destination browsing, destination models, destination cards, destination details, galleries, saved destination interactions, and presentation widgets. It supports search, filtering, image display, and destination detail exploration.

`/features/map/` contains the interactive map screen, route display, navigation overlay, marker handling, map controls, tile switching, offline map status, and navigation UI. This feature integrates with `flutter_map`, MBTiles providers, geolocation, route services, and destination markers.

`/features/chatbot/` contains the tourism chatbot UI, chat message models, chatbot service wrappers, online LLM API service, and offline chat screen. It allows users to ask tourism questions and receive local NLP responses.

`/features/recommendations/` contains personalized recommendation screens and logic. It presents suggested destinations based on user preferences and destination attributes. It can use backend recommendations when available and local cached recommendations when offline.

`/features/auth/` contains user authentication screens and API integration. It supports account registration, login, and session handling when backend connectivity is available.

`/features/account/` contains user profile management, preferences, and account-related UI. It allows users to personalize their tourism experience by selecting interests or updating profile information.

`/features/about/` contains app information, project context, and informational screens.

Additional feature folders such as `home`, `shell`, `translator`, `profile`, `onboarding`, `intelligence`, and `trip_planner` support the broader app experience. The `shell` feature coordinates bottom navigation and tab layout. The `home` feature provides discovery. The `intelligence` feature contains advanced local NLP and chatbot components.

[DIAGRAM: Feature folder architecture tree showing app/lib/core for shared services and app/lib/features for destinations, map, chatbot, recommendations, auth, account, about, home, shell, translator, and intelligence.]

## 3.3 Offline Architecture

The offline routing architecture is one of the most important parts of the application. It uses a three-tier strategy:

**Tier 1: SQLite Route Cache.** Before any network request, the app checks `RouteCache`. The cache key is deterministic and includes origin latitude, origin longitude, destination latitude, destination longitude, and travel mode. Cached routes expire after 30 days. If a valid cached route exists, it is returned immediately. This allows previously requested online routes to remain usable offline.

**Tier 2: Online OSRM Routing.** If no valid cached route exists, the app attempts online routing through the OSRM public demo server. The request uses the route endpoint with origin and destination coordinates, full geometry, GeoJSON format, steps enabled, and annotations disabled. The timeout is 12 seconds. If the response succeeds, the app parses the route geometry, distance, duration, and step instructions, then saves the result to SQLite cache.

**Tier 3: Haversine Straight-Line Fallback.** If OSRM fails because the user is offline, the server times out, or the response cannot be parsed, the app computes an approximate offline route. It uses the Haversine formula to calculate great-circle distance between origin and destination. The displayed polyline contains two points: origin and destination. Duration is estimated by travel mode: driving at 60 km/h, walking at 5 km/h, and cycling at 15 km/h. The route result is marked with `isFallback = true`, allowing the UI to show a warning that the route is approximate and internet is required for turn-by-turn navigation.

This architecture prevents the app from failing when routing is unavailable. It also balances accuracy and reliability: cached and online OSRM routes provide road-aware routes, while fallback routes provide last-resort guidance.

[DIAGRAM: Three-tier routing flow. Start: user requests route. Step 1: check SQLite RouteCache. If hit, return cached route. If miss, call online OSRM. If success, save and return route. If failure, compute Haversine fallback and return approximate route.]

## 3.4 Data Architecture

The application uses multiple local data sources:

1. `assets/data/destinations.json` stores 300 curated destinations for Gandaki Province. This asset is bundled with the app and can be read without internet connectivity.

2. `assets/destination_images/` stores 300 optimized WebP destination images. These images allow the app to show destination photos offline and avoid broken placeholders.

3. `assets/maps/pokhara.mbtiles` stores raster PNG map tiles for Pokhara and surrounding Gandaki areas. The file size is 8,171,520 bytes, and it contains zoom levels 7 to 12. The map package is focused on the target region to keep the APK size practical.

4. SQLite databases store saved destinations, recommendation cache, and route cache. SQLite is appropriate because it provides persistent local storage, structured queries, and reliable mobile support.

5. SharedPreferences stores lightweight user settings such as selected map style, user preference choices, and app-level flags.

6. Backend API data is used only when available. The backend can provide AI enhancement, recommendation sync, image lookup, and analytics. However, the mobile app does not depend on the backend for its core offline functions.

The data architecture is intentionally redundant in a useful way. Destination data exists locally even if the backend is unreachable. Images exist locally even if Wikipedia or backend image lookup fails. Routes can exist in cache even if OSRM becomes unreachable. This redundancy is central to offline-first reliability.

## 3.5 State Management

Paila Nepal uses Flutter Riverpod for reactive state management and service injection where appropriate. Riverpod supports a provider-based architecture in which widgets can observe and react to state changes without tightly coupling UI code to service implementation. This is useful for recommendation results, user profile data, async loading states, settings, and shared services.

In addition to Riverpod, some screens use local `StatefulWidget` state for UI-specific behavior such as animation controllers, selected filters, bottom sheet state, text controllers, map controller updates, and temporary loading flags. This mixed approach is practical: global or shared state is managed through providers, while short-lived screen state remains local to the screen.

Singleton patterns are used for services that represent shared local resources. `LocalDataService` manages app database access. `RouteCache` manages the route cache database. Singleton initialization avoids repeatedly opening database connections and provides a consistent access point for persistence.

The state management strategy can be summarized as:

- Riverpod for reactive app-level state and dependency access.
- Local widget state for transient UI behavior.
- Singleton services for database-backed persistence.
- Async service methods for loading assets, route data, images, and backend responses.

This approach supports both responsiveness and maintainability. Offline operations can update UI state immediately without waiting for a network result.

## 3.6 Database Schema

The mobile app uses SQLite tables for key offline data.

### saved_destinations

| Column | Type | Description |
|---|---|---|
| id | TEXT PRIMARY KEY | Unique destination identifier |
| payload | TEXT | JSON-encoded destination payload |
| saved_at | INTEGER | Timestamp when the destination was saved |

This table stores destinations saved by the user. The payload keeps the full destination data so saved destinations can be displayed offline even if the source dataset changes.

### recommendation_cache

| Column | Type | Description |
|---|---|---|
| cache_key | TEXT PRIMARY KEY | Deterministic key based on preferences/request |
| payload | TEXT | JSON-encoded recommendation result |
| generated_at | INTEGER | Timestamp when recommendations were generated |

This table allows recommendations to remain visible when the backend is unavailable. It supports cached AI recommendations and local fallback behavior.

### cached_routes

| Column | Type | Description |
|---|---|---|
| key | TEXT PRIMARY KEY | Route key built from origin, destination, and travel mode |
| data | TEXT | JSON-encoded `RouteResult` |
| cached_at | INTEGER | Timestamp when the route was cached |

This table supports the first tier of the routing architecture. Cached routes expire after 30 days to avoid stale results while still improving offline usability.

---

# Chapter 4: Implementation

**Page 21**

## 4.1 Technology Stack

| Component | Technology | Version |
|---|---|---|
| Framework | Flutter | SDK >= 3.0.0 |
| Language | Dart | 3.x |
| State Management | flutter_riverpod | 3.3.1 |
| Maps | flutter_map | 8.2.2 |
| Offline Tiles | flutter_map_mbtiles | 1.0.4 |
| Routing | OSRM + Haversine fallback | - |
| Database | sqflite | 2.3.3+1 |
| Connectivity | connectivity_plus | 7.1.1 |
| Location | geolocator | 14.0.1 |
| Networking | http | 1.2.0 |
| Fonts | google_fonts (Outfit) | 6.2.1 |
| Images | cached_network_image | 3.4.1 |
| Analytics | PostHog + Sentry | posthog_flutter 5.24.2, sentry_flutter 9.0.0 |
| Speech | speech_to_text + flutter_tts | speech_to_text 7.0.0, flutter_tts 3.8.5 |
| Backend | FastAPI | Python |
| Backend Database | PostgreSQL / SQLite fallback | - |

Flutter was selected because it supports rapid development of a polished mobile UI, consistent rendering across devices, and access to strong plugin support. Dart provides null-safety and async programming features that are useful for file loading, HTTP requests, database operations, and UI state updates. `flutter_map` provides open map rendering without depending on Google Maps SDK or paid services. `flutter_map_mbtiles` enables local MBTiles tile loading. `sqflite` provides local database persistence. `connectivity_plus` detects network availability. `geolocator` supports user location and navigation features.

The backend uses FastAPI for API endpoints such as health checks, chat, recommendations, authentication, translation, image lookup, and data services. Docker Compose runs the backend and PostgreSQL for production-style local deployment. The mobile application remains useful even when the backend is stopped, which is a major design requirement.

## 4.2 Offline Map Implementation

The offline map implementation uses a local MBTiles file named `pokhara.mbtiles`, stored under `assets/maps/`. The file is a raster PNG MBTiles database, approximately 7.8 MB, focused on Gandaki Province with zoom levels 7 to 12. This scope provides a balance between usable map coverage and APK size. A full Nepal map at higher zoom levels would be much larger and less practical for a student project APK.

MBTiles is a SQLite database format for tiled map data. A typical MBTiles database includes metadata and a `tiles` table containing zoom level, tile column, tile row, and tile data. In this project, each tile is a PNG image. Raster tiles are compatible with the MBTiles provider used in the Flutter app. Earlier vector PBF tiles were not suitable because the selected provider expected raster tile bytes for display.

The map tiles were generated by downloading raster PNG tiles from the OpenStreetMap tile server for the Gandaki bounding box. The target bounding box was approximately 83.4 to 85.2 longitude and 27.8 to 29.2 latitude. Tiles were packaged into a valid MBTiles SQLite database. The file was then bundled as a Flutter asset.

The app uses an offline tile provider that validates the MBTiles file before using it. Validation includes:

- Checking that the file exists.
- Checking that the file is above a minimum useful size threshold.
- Checking the SQLite magic header.
- Avoiding unnecessary recopying of the asset when the destination file already exists and matches the expected size.
- Applying a loading timeout so the app can gracefully fall back to online tiles if local tile initialization fails.

If the MBTiles file is unavailable or fails validation, the app can fall back to online CartoDB Voyager, CartoDB Positron, CartoDB Dark Matter, or OpenStreetMap tiles depending on the selected style. The map screen includes status indicators for online/offline map state.

The map layer also uses `maxNativeZoom: 14`, `tileSize: 256`, and a keep buffer. Although the MBTiles file contains zoom levels up to 12, `maxNativeZoom` allows tile scaling beyond the native zoom level and prevents blank tiles when the user zooms in slightly beyond the available tile range. This improves the user experience while preserving a small map file.

[DIAGRAM: Offline map loading sequence. App starts map screen, validates MBTiles asset, copies or reuses local MBTiles file, creates MbTilesTileProvider, displays raster tiles. If validation fails, map uses online CartoDB or OSM tile URL.]

## 4.3 Routing Service Implementation

The routing service is implemented around `RoutingService`, `RouteCache`, `RouteResult`, `RouteStep`, and supporting geospatial utilities. A route request begins with an origin `LatLng`, destination `LatLng`, and travel mode. Supported travel modes include driving, walking, and cycling.

`RouteCache.buildKey()` creates a deterministic key in the form:

```text
originLat,originLng->destLat,destLng->travelMode
```

This key uniquely identifies a route for a specific origin, destination, and travel mode. Before making a network call, `RoutingService` calls `RouteCache.get(key)`. If the cached result exists and is not older than 30 days, it is returned immediately.

If the cache does not contain a valid route, the service attempts OSRM routing. The OSRM endpoint follows this structure:

```text
http://router.project-osrm.org/route/v1/{mode}/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=geojson&steps=true&annotations=false
```

The service uses a 12-second timeout. If the response is successful, the route geometry is parsed from GeoJSON coordinates. OSRM returns coordinates in longitude-latitude order, so the implementation converts them to `LatLng(latitude, longitude)`. Step information is parsed from the route legs, including instruction text, distance, duration, maneuver type, maneuver direction, and location.

If OSRM fails, the service calls its fallback route method. The fallback uses `haversineKm()` to compute distance between origin and destination. Distance in kilometers is converted to meters. Duration is estimated using travel-mode speeds:

- Driving: 60 km/h
- Walking: 5 km/h
- Cycling: 15 km/h

The fallback route contains only two polyline points: origin and destination. It also contains a single route step with the instruction "Approximate route - internet required for turn-by-turn." The `RouteResult.isFallback` flag is set to true. The map UI uses this flag to show a warning such as "Approximate route only."

This implementation guarantees that route loading does not result in an infinite spinner or crash when offline. It gives the user the best available guidance based on current conditions.

## 4.4 Chatbot Implementation

The chatbot is implemented as a layered local intelligence feature. The basic `ChatbotService` loads a tourism knowledge base from `assets/data/chatbot_knowledge_base.json`. This file contains intent keywords, example phrases, destination aliases, and response templates. When the user enters a question, the chatbot normalizes the input, extracts tokens, matches destination names and aliases, classifies intent, and builds a response.

Intent classification uses keyword matching with weighted scoring. For example, words such as "season," "weather," "month," "spring," and "autumn" increase the score for a best-time-to-visit intent. Words such as "homestay," "room," "stay," or "accommodation" increase the homestay intent score. Destination names and aliases are matched against the local destination list so the response can mention a specific place.

The chatbot includes emergency detection. If a query contains safety-critical language such as "ambulance," "police," "injured," "lost," "accident," or "emergency," the chatbot prioritizes emergency guidance. This is important because rural travelers may use the app in unfamiliar or risky conditions.

`ChatbotServiceAdvanced` supports more complex local dialogue and response generation. It works with an intelligence orchestrator containing components such as NLP pipeline, intent classifier, dialogue manager, RAG pipeline, safety layer, translation manager, and optional online enhancement. The offline response path remains local and asset-based.

`LlmChatApiService` supports online enhanced responses by contacting the FastAPI backend when available. The backend can use configured providers such as Groq or Gemini. If no AI provider key is configured, the chat UI now shows a clear banner explaining that AI chat is in offline mode and that the developer should add `GROQ_API_KEY` or `GEMINI_API_KEY` to `backend/.env` and restart Docker. This improves developer and demo clarity.

The chatbot therefore has two modes:

- Offline mode: local NLP, local knowledge base, emergency detection, templates, and destination-aware answers.
- Online enhanced mode: backend LLM responses using configured AI providers.

The offline mode is the dependable base layer; online AI is an enhancement, not a requirement.

## 4.5 Recommendation System

The recommendation system helps users discover destinations based on preferences and destination attributes. It uses content-based filtering on the mobile side and backend-assisted hybrid recommendation when available.

Each destination includes structured attributes such as category, activities, best season, budget level, accessibility, family-friendliness, adventure level, culture level, nature level, tags, and descriptions. User preferences can include desired activities, budget, season, family needs, adventure preference, cultural interest, and nature interest.

The mobile recommendation process can be described as:

1. Load destination data from local JSON assets.
2. Read user preferences from local settings or profile.
3. Score each destination according to attribute matches.
4. Apply context adjustments such as season, budget, accessibility, and family suitability.
5. Sort destinations by score.
6. Display recommendations with confidence labels or reasons.
7. Cache results locally for offline reuse.

The backend can provide more advanced ranking through semantic retrieval, collaborative signals, popularity fallback, contextual reranking, and explainable score breakdown. However, the app is not dependent on the backend to show recommendations. When offline, it can use local data and cached results.

This design is appropriate for rural tourism because users often begin with broad preferences such as "peaceful village," "family-friendly nature place," "budget trekking route," or "cultural homestay." Content-based matching is effective because each destination is richly described through structured fields.

## 4.6 Destination Data

The app includes 300 destinations across Gandaki Province. Each destination record contains:

- `id`
- `name`
- `province`
- `district`
- `municipality`
- `category[]`
- `activities[]`
- `bestSeason[]`
- `budgetLevel`
- `accessibility`
- `familyFriendly`
- `adventureLevel`
- `cultureLevel`
- `natureLevel`
- `shortDescription`
- `fullDescription`
- `latitude`
- `longitude`
- `tags[]`
- `images[]`

Destination categories include trekking, cultural, nature, village, wildlife, boating, spiritual, relaxation, pilgrimage, photography, scenic, and historic. These categories support filtering, recommendation, chatbot answers, and fallback image selection.

The project also includes 300 local WebP images in `assets/destination_images/`. WebP was selected because it provides good compression while preserving acceptable visual quality. The total local image pack is approximately 8.7 MB, which is practical for APK bundling. A manifest maps destination names to local image assets so the UI can load the correct image without network calls.

Destination images improve user experience significantly. A tourism app without images feels incomplete, especially when users are browsing unfamiliar places. By bundling local images, the app preserves visual discovery offline.

## 4.7 Key Screens

### Home / Discovery Screen

The home screen presents destination discovery, categories, featured places, offline status indicators, and quick access to major app sections. It supports browsing and introduces the user to rural destinations visually.

### Map Screen

The map screen uses `flutter_map` to display destination markers over local or online tiles. It supports offline MBTiles, tile style switching, destination marker taps, route rendering, current-location markers, route summaries, and navigation overlays. When a user selects a destination, the app can draw a route using cached, online, or fallback routing.

### Destination Details Screen

The destination details screen displays images, descriptions, categories, activities, location information, seasonal guidance, accommodation details, and navigation actions. It is designed to help users decide whether and when to visit a destination.

### Chatbot Screen

The chatbot screen provides conversational tourism assistance. It supports local offline answers, online enhancement when configured, speech input, text-to-speech, translation actions, quick suggestions, source badges, confidence indicators, and emergency response formatting.

### Saved Screen

The saved screen displays destinations stored locally by the user. Saved places are stored in SQLite so they remain accessible offline.

### Recommendations Screen

The recommendations screen shows personalized destination suggestions based on preferences. It includes filters and action buttons that help users refine recommendation criteria.

### Account Screen

The account screen manages user profile information, preferences, and authentication-related settings. It supports personalization while preserving guest/offline behavior.

### About Screen

The about screen presents information about the app, project context, purpose, and system identity.

[DIAGRAM: Screen navigation diagram showing bottom navigation shell linking Home, Map, Chatbot, Recommendations, Saved/Profile, and About flows. Destination cards link to Destination Details, and Destination Details links to Map Navigation.]

---

# Chapter 5: Testing and Results

**Page 32**

## 5.1 Testing Strategy

Testing focused on functional correctness, offline resilience, performance, and build stability. The project includes automated Flutter tests, backend tests, and manual Android testing.

Unit tests validate components such as chatbot intent detection, intent classification, retrieval logic, translation behavior, widget rendering, and recommendation UI elements. Golden tests validate the visual stability of destination cards. Backend tests validate API behavior and service functionality.

Integration-style testing focuses on online/offline transitions. This includes starting the app with the backend unavailable, disabling internet access, tapping destination markers, loading map tiles, checking route fallback behavior, querying the chatbot, and verifying local saved destinations.

Manual testing was performed on Android debug builds. Scenarios included cold start, map opening, route drawing, destination detail navigation, chatbot questions, recommendation filtering, offline map display, and backend connectivity checks.

The following validation commands were used during final project checks:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
python -m pytest backend/tests -q
docker compose config -q
```

These commands confirm dependency resolution, static analysis, Flutter tests, Android build generation, backend tests, and Docker Compose configuration validity.

## 5.2 Offline Functionality Testing

| Test Case | Expected | Result |
|---|---|---|
| Map loads with no internet | MBTiles tiles display | Pass |
| Tap destination offline | Straight-line route shown | Pass |
| Cached route loads offline | Cached route displayed | Pass |
| Chatbot query offline | Local NLP response | Pass |
| Saved destinations offline | SQLite data loads | Pass |
| App launch offline | All 300 destinations load | Pass |

Offline testing is central to this project because the app's main promise is reliability without connectivity. The tests show that the core destination discovery and guidance workflow continues when network access is unavailable. Map tiles load locally from MBTiles, destination data loads from JSON assets, images load from bundled WebP files, chatbot responses come from local knowledge, and saved destinations come from SQLite.

Route testing confirms that users are not left with a failed request when OSRM is unavailable. If a cached route exists, it loads from SQLite. If no route exists, the Haversine fallback route is displayed with an approximate-route warning. This behavior is safer and more transparent than silently failing.

## 5.3 Performance Results

| Metric | Result |
|---|---|
| App cold start | < 3 seconds |
| MBTiles tile load | < 500 ms per tile |
| Offline route fallback | < 100 ms |
| Cached route load | < 200 ms |
| Online route through OSRM | 1-3 seconds |
| Chatbot local response | < 500 ms |
| Destination search | < 100 ms |

The performance results show that local operations are fast enough for practical mobile use. Offline route fallback is extremely fast because it performs only a mathematical distance calculation and simple object creation. Cached route loading is also fast because it reads a single SQLite row. Chatbot local responses are fast because they use local intent matching and templates rather than cloud inference.

Online route requests depend on network conditions and the public OSRM demo server. The 12-second timeout prevents indefinite waiting. In typical connected conditions, OSRM responses arrive within one to three seconds, but the app remains stable even if the request fails.

## 5.4 APK Size Analysis

| Component | Size |
|---|---|
| Flutter engine | ~8 MB |
| App code + Dart | ~5 MB |
| Destination images (300 WebP) | ~8.7 MB |
| MBTiles (Gandaki, zoom 7-12) | ~8 MB |
| Other assets (JSON, fonts, animations) | ~5 MB |
| Total APK | ~41 MB |

The APK size is reasonable for an offline-first tourism app. Offline assets naturally increase package size, but this tradeoff is intentional. A purely online app could be smaller, but it would fail in low-connectivity rural environments. Paila Nepal bundles essential data while keeping the map scope and image compression optimized.

The most important size optimization was reducing the map package from an earlier 290 MB file to an 8 MB Gandaki-focused MBTiles file. The second major optimization was using compressed WebP images for destination photographs. Together, these choices make the app suitable for distribution and demonstration while preserving offline functionality.

---

# Chapter 6: Challenges and Solutions

**Page 37**

## 6.1 Offline Map Tile Format

One of the first major challenges was offline map tile compatibility. Some map tile tools provide vector PBF tiles. Vector tiles are efficient and flexible, but they require a vector tile renderer and style pipeline. The selected Flutter MBTiles provider expected raster image tiles. When vector PBF tiles were used, the map displayed blank tiles because the bytes could not be interpreted as PNG or JPEG images.

The solution was to generate raster PNG MBTiles instead. A custom Python script downloaded raster tiles from the OpenStreetMap tile server and stored them in a valid SQLite MBTiles database. Raster PNG tiles could then be loaded directly by `flutter_map_mbtiles`. This solved the blank map display issue and simplified rendering.

## 6.2 MBTiles TMS vs XYZ Coordinate System

Another challenge was coordinate system mismatch. Web map tiles are commonly referenced using XYZ coordinates, where the tile row starts from the top. MBTiles often stores tile rows using TMS coordinates, where the y-axis origin is at the bottom. If this mismatch is not handled, tile cropping or lookup can fail.

During cropping, the mismatch caused zero tiles to be copied because the expected tile row values did not match the stored values. The solution was to apply the y-flip formula:

```text
tms_y = (2^zoom - 1) - xyz_y
```

This conversion correctly maps XYZ tile rows to TMS tile rows. After applying the formula, the tile cropping process selected the correct tiles for the Gandaki bounding box.

## 6.3 Large File Size

The original full Nepal MBTiles file was approximately 290 MB. This size was too large for practical Flutter asset bundling and could cause long build times, APK bloat, and app startup problems. A student project APK should remain manageable for installation on physical devices and demonstration environments.

The solution was to crop the map to the target region. Since the app focuses on Gandaki Province, the map package was reduced to a bounding box around Pokhara and surrounding rural areas. The resulting MBTiles file is approximately 7.8 MB. This greatly improved build practicality while preserving the required regional map coverage.

The app also includes logic to avoid recopying large MBTiles files unnecessarily. It checks whether the destination file already exists and matches the expected size before copying from assets. This reduces startup overhead.

## 6.4 Offline Routing

OSRM routing requires internet connectivity unless a routing engine and road graph are self-hosted locally. A mobile app cannot realistically bundle a full routing engine and regional graph without significant complexity and size overhead. Therefore, relying only on OSRM would break the offline-first requirement.

The solution was the three-tier routing strategy:

1. Check SQLite route cache.
2. Attempt online OSRM routing.
3. Use Haversine fallback if OSRM fails.

This design ensures the app always provides a result. Cached routes provide accurate previously fetched routes. OSRM provides accurate road-aware routes when online. Haversine fallback provides approximate distance and direction when offline. The UI clearly labels fallback routes as approximate, maintaining honesty and user safety.

## 6.5 Vector vs Raster Tiles

Vector and raster tiles differ significantly. Vector tiles store geographic features such as roads, landuse polygons, and labels in a compact structured format. They require styling and rendering at runtime. Raster tiles store pre-rendered images. They are larger for some use cases but easier to display because the app only needs to decode and draw image bytes.

The project initially encountered blank display problems with vector PBF MBTiles. The final solution used raster PNG tiles because they are compatible with the selected Flutter map provider. This was an important engineering decision: a theoretically advanced tile format is not useful if it does not match the rendering library. The final implementation prioritizes reliability, compatibility, and demonstration readiness.

---

# Chapter 7: Conclusion and Future Work

**Page 43**

## 7.1 Summary of Achievements

Paila Nepal successfully demonstrates an offline-first rural tourism mobile application for Gandaki Province. The project integrates mobile UI development, local data storage, map engineering, routing fallback, chatbot assistance, recommendation logic, backend services, and asset optimization.

The major achievements are:

- A Flutter Android application with a polished rural tourism experience.
- 300 curated Gandaki Province destinations available offline.
- 300 bundled WebP destination images for offline visual browsing.
- Offline MBTiles map display for Pokhara and surrounding Gandaki areas.
- Destination markers on an interactive `flutter_map` screen.
- Route display using cache, OSRM, or Haversine fallback.
- Offline chatbot using local NLP and knowledge-base responses.
- Emergency detection for safety-critical queries.
- Personalized recommendation support based on destination attributes and user preferences.
- SQLite storage for saved destinations, recommendation cache, and route cache.
- SharedPreferences storage for app settings and preferences.
- FastAPI backend integration for online enhancements.
- Docker Compose setup with PostgreSQL and image prefetching.
- APK size optimized to approximately 41 MB.

The project meets its central objective: travelers can still discover destinations, view maps, ask basic tourism questions, save places, and get approximate route guidance without internet connectivity.

## 7.2 Future Work

Future work can improve the project in several directions.

First, map detail can be improved by adding zoom levels 13 and 14 for street-level rural navigation. This would increase the MBTiles file size, so the map area and compression strategy would need careful planning.

Second, true offline turn-by-turn routing can be added by self-hosting OSRM, Valhalla, or GraphHopper and generating a regional routing graph. For mobile offline use, the app would need either an embedded routing engine or a local server-like component, which is complex but valuable.

Third, coverage can expand beyond Gandaki Province to all Nepal provinces. This would require additional destination curation, image collection, map generation, and performance optimization.

Fourth, iOS support can be added. Flutter makes this possible, but platform-specific testing, permissions, map asset handling, and distribution workflows would need to be completed.

Fifth, augmented reality destination previews could help travelers identify nearby places, viewpoints, and cultural landmarks through the camera.

Sixth, community-contributed reviews, corrections, and destination updates could improve the dataset. This would require moderation, sync logic, account trust, and conflict handling.

Seventh, multi-language support can be expanded for Nepali and English users, with improved translation, local phrasebook, and offline Roman Nepali handling.

Finally, production deployment could include a hosted backend, analytics dashboard, content management system, automated map tile generation, and periodic destination data updates.

## 7.3 Final Remarks

Paila Nepal shows that rural tourism applications should not be designed as online-only services. In regions such as Gandaki Province, the absence of reliable connectivity is not an exception; it is part of the real user environment. By designing around offline capability from the beginning, the project provides a more dependable and locally appropriate tourism tool.

The application also demonstrates that offline-first design is not limited to simple cached pages. A full offline-first tourism app can include structured destination data, local images, map tiles, routing fallback, chatbot responses, saved places, recommendation logic, and online enhancement. The result is a practical, technically complete, and socially relevant mobile application for rural tourism in Nepal.

---

# References

**Page 47**

1. Flutter. (2026). *Flutter - Build apps for any screen*. Retrieved from https://flutter.dev/

2. OpenStreetMap. (2026). *About OpenStreetMap*. Retrieved from https://www.openstreetmap.org/about

3. Mapbox. (2026). *MBTiles Specification*. Retrieved from https://github.com/mapbox/mbtiles-spec

4. Project OSRM. (2026). *OSRM API Documentation*. Retrieved from https://project-osrm.org/docs/

5. flutter_map. (2026). *flutter_map package*. Pub.dev. Retrieved from https://pub.dev/packages/flutter_map

6. Riverpod. (2026). *Riverpod documentation*. Retrieved from https://riverpod.dev/

7. Android Developers. (2026). *Build an offline-first app*. Retrieved from https://developer.android.com/topic/architecture/data-layer/offline-first

8. Inman, J. (1835). *Navigation and Nautical Astronomy: For the Use of British Seamen* (3rd ed.). London. Historical source associated with the term haversine and navigation calculations.

9. Haversine Formula. (2026). *Haversine formula*. Retrieved from https://en.wikipedia.org/wiki/Haversine_formula

10. Baral, R., & Saini, V. K. (2025). *Nepalese tourism from the lens of residents: An assessment of impact perception, attitude, and action towards tourism development in Gandaki province, Nepal*. Tourism and Hospitality Research. Retrieved from https://journals.sagepub.com/doi/10.1177/14673584241232850

11. Gavalas, D., Konstantopoulos, C., Mastakas, K., & Pantziou, G. (2014). *Mobile recommender systems in tourism*. Journal of Network and Computer Applications, 39, 319-333.

12. Borras, J., Moreno, A., & Valls, A. (2014). *Intelligent tourism recommender systems: A survey*. Expert Systems with Applications, 41(16), 7370-7389.

13. Felfernig, A., et al. (2023). *A Novel Hybrid Recommender System for the Tourism Domain*. Algorithms, 16(4), 215. Retrieved from https://www.mdpi.com/1999-4893/16/4/215

14. Ricci, F., Rokach, L., & Shapira, B. (2015). *Recommender Systems Handbook* (2nd ed.). Springer.

15. OpenStreetMap Wiki. (2026). *What is OpenStreetMap?* Retrieved from https://wiki.openstreetmap.org/wiki/What_is_OpenStreetMap%3F

16. Pub.dev. (2026). *flutter_riverpod package*. Retrieved from https://pub.dev/packages/flutter_riverpod

17. Mapbox. (2026). *MBTiles glossary*. Retrieved from https://docs.mapbox.com/help/glossary/mbtiles/

18. Data and Systems Research. (2024). *Offline-First Mobile Architecture: Enhancing Usability and Resilience in Mobile Systems*. Nigerian Journal of Artificial Intelligence and General Studies, 7(1), 320-326.

---

# Appendix A: Suggested Page Numbering for PDF Conversion

When converting this Markdown document to PDF or DOCX, use Roman numerals for the title page, abstract, and table of contents, then restart Arabic numbering at Chapter 1. The page labels included in this Markdown file are placeholders to satisfy draft review and can be replaced by automatic page numbering in Microsoft Word, Google Docs, or LaTeX.

# Appendix B: Report Preparation Notes

- Replace `[Student Name]`, `[Roll No]`, `[Department]`, and `[University Name]` before submission.
- Update screenshots and diagrams if the department requires visual figures.
- If the final APK size differs from the estimate, replace the APK size table with the measured release APK size.
- If the map coverage expands beyond Gandaki Province, update the scope, limitations, and future work sections.
- If the backend is deployed publicly, add deployment URL, server configuration, and security details.
