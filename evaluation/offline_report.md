# Offline Recommender Evaluation

Generated: 2026-05-28T19:55:28.458439Z

Dataset:

- Destinations: 300
- Accommodations: 771
- Province scope: Gandaki only

Engine under test:

- Hybrid TF-IDF + BM25 retrieval
- Offline semantic destination embeddings
- Numeric traveler profile matching
- Contextual reranking
- Accommodation, quality, and cold-start priors
- District/category diversification

## Aggregate

| Metric | Advanced Offline | Basic Baseline | Delta |
| --- | ---: | ---: | ---: |
| Precision@10 | 1.0000 | 1.0000 | +0.0000 |
| Recall@10 | 0.0387 | 0.0387 | +0.0000 |
| nDCG@10 | 0.9252 | 0.8376 | +0.0876 |
| MRR | 1.0000 | 1.0000 | +0.0000 |

Coverage across evaluation profiles:

| Coverage | Advanced Offline | Basic Baseline | Delta |
| --- | ---: | ---: | ---: |
| Catalog | 23.0% | 20.3% | +2.7% |
| District | 100.0% | 100.0% | +0.0% |
| Category | 87.5% | 100.0% | -12.5% |

## Profile Results

| Profile | P@10 | R@10 | nDCG@10 | MRR | Baseline nDCG | Top result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Family lake escape | 1.0000 | 0.0340 | 1.0000 | 1.0000 | 1.0000 | Bahunthan Hill |
| High adventure trek | 1.0000 | 0.0383 | 1.0000 | 1.0000 | 1.0000 | Larkya La Pass |
| Cultural homestay | 1.0000 | 0.0346 | 1.0000 | 1.0000 | 1.0000 | Khasur Village |
| Pilgrimage route | 1.0000 | 0.0463 | 1.0000 | 1.0000 | 0.9621 | Matepani Gumba |
| Wildlife and nature | 1.0000 | 0.0442 | 0.9535 | 1.0000 | 0.8637 | Namuna Community Forest |
| Scenic photography | 1.0000 | 0.0369 | 0.7672 | 1.0000 | 0.7275 | Poon Hill |
| Budget relaxation | 1.0000 | 0.0398 | 0.8017 | 1.0000 | 0.4286 | Pame |
| Heritage and market culture | 1.0000 | 0.0353 | 0.8787 | 1.0000 | 0.7186 | International Mountain Museum |

### Family lake escape

Low-cost, easy, family-friendly lakeside recommendation.

| Rank | Destination | District | Category | Score | Grade | Why |
| ---: | --- | --- | --- | ---: | ---: | --- |
| 1 | Bahunthan Hill | Syangja | boating | 0.8101 | 3 | Strong offline semantic match to your travel profile (19%); Feature profile matches your preferred trip style (18%) |
| 2 | Rupa Lake | Kaski | boating | 0.7770 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (17%) |
| 3 | Dudhpokhari | Lamjung | boating | 0.7750 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (17%) |
| 4 | Phewa Lake | Kaski | boating | 0.7726 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (16%) |
| 5 | Davis Falls (Patale Chhango) | Kaski | boating | 0.7653 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (15%) |
| 6 | Begnas Lake | Kaski | boating | 0.7648 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (17%) |
| 7 | Dhumba Lake | Mustang | boating | 0.7621 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (17%) |
| 8 | World Peace Pagoda | Kaski | boating | 0.7613 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (15%) |
| 9 | Ilam Pokhari Lamjung | Lamjung | boating | 0.7613 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (16%) |
| 10 | Suntalabari | Syangja | boating | 0.7612 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (14%) |

### High adventure trek

Demanding mountain routes for adventure travelers.

| Rank | Destination | District | Category | Score | Grade | Why |
| ---: | --- | --- | --- | ---: | ---: | --- |
| 1 | Larkya La Pass | Gorkha | trekking | 0.7784 | 3 | Feature profile matches your preferred trip style (17%); Strong offline semantic match to your travel profile (17%) |
| 2 | Devchuli Trail | Nawalpur | trekking | 0.7732 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (16%) |
| 3 | Gaindakot | Nawalpur | trekking | 0.7584 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (15%) |
| 4 | Hupsekot | Nawalpur | trekking | 0.7580 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (15%) |
| 5 | Thorong La Pass | Manang | trekking | 0.7571 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (17%) |
| 6 | Bahundanda | Lamjung | trekking | 0.7569 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (15%) |
| 7 | Bhanu Danda | Tanahun | trekking | 0.7567 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (15%) |
| 8 | Mirlungkot | Tanahun | trekking | 0.7564 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (15%) |
| 9 | Kotre | Tanahun | trekking | 0.7558 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (15%) |
| 10 | Hemjakot | Kaski | trekking | 0.7542 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (15%) |

### Cultural homestay

Village culture, homestay, food, and accessible local life.

| Rank | Destination | District | Category | Score | Grade | Why |
| ---: | --- | --- | --- | ---: | ---: | --- |
| 1 | Khasur Village | Lamjung | village | 0.8040 | 3 | Feature profile matches your preferred trip style (18%); Offline embedding match understands related travel intent (15%) |
| 2 | International Mountain Museum | Kaski | cultural | 0.7991 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (16%) |
| 3 | Marpha | Mustang | pilgrimage | 0.7455 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (14%) |
| 4 | Laprak | Gorkha | village | 0.7643 | 3 | Feature profile matches your preferred trip style (19%); Offline embedding match understands related travel intent (15%) |
| 5 | Maharajathan Temple | Nawalpur | pilgrimage | 0.7454 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (12%) |
| 6 | Ghandruk | Kaski | trekking | 0.7401 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (14%) |
| 7 | Ghalegaun | Lamjung | cultural | 0.7701 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (14%) |
| 8 | Kaulepani | Lamjung | village | 0.7590 | 3 | Feature profile matches your preferred trip style (19%); Offline embedding match understands related travel intent (15%) |
| 9 | Shikha Village | Myagdi | village | 0.7576 | 3 | Feature profile matches your preferred trip style (19%); Offline embedding match understands related travel intent (14%) |
| 10 | Dagnam Village | Myagdi | village | 0.7576 | 3 | Feature profile matches your preferred trip style (19%); Offline embedding match understands related travel intent (14%) |

### Pilgrimage route

Budget spiritual sites with family-friendly access.

| Rank | Destination | District | Category | Score | Grade | Why |
| ---: | --- | --- | --- | ---: | ---: | --- |
| 1 | Matepani Gumba | Kaski | pilgrimage | 0.8391 | 3 | Strong offline semantic match to your travel profile (18%); Feature profile matches your preferred trip style (17%) |
| 2 | Ramrekha Dham | Baglung | pilgrimage | 0.8170 | 3 | Strong offline semantic match to your travel profile (18%); Feature profile matches your preferred trip style (18%) |
| 3 | Jaimini Dham | Baglung | pilgrimage | 0.8151 | 3 | Strong offline semantic match to your travel profile (18%); Feature profile matches your preferred trip style (18%) |
| 4 | Shashwat Dham | Nawalpur | pilgrimage | 0.8104 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (17%) |
| 5 | Galeshwor Dham | Myagdi | pilgrimage | 0.8089 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (15%) |
| 6 | Maulakalika Temple | Nawalpur | pilgrimage | 0.8065 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (17%) |
| 7 | Devghat Dham | Tanahun | pilgrimage | 0.8057 | 3 | Feature profile matches your preferred trip style (18%); Offline embedding match understands related travel intent (15%) |
| 8 | Triveni Dham (Nawalpur) | Nawalpur | pilgrimage | 0.8054 | 3 | Feature profile matches your preferred trip style (18%); Offline embedding match understands related travel intent (14%) |
| 9 | Baglung Kalika Temple | Baglung | pilgrimage | 0.8039 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (15%) |
| 10 | Daunne Devi Temple | Nawalpur | pilgrimage | 0.7982 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (14%) |

### Wildlife and nature

Community forests, birding, river plains, and lowland nature.

| Rank | Destination | District | Category | Score | Grade | Why |
| ---: | --- | --- | --- | ---: | ---: | --- |
| 1 | Namuna Community Forest | Nawalpur | wildlife | 0.8197 | 3 | Strong offline semantic match to your travel profile (21%); Feature profile matches your preferred trip style (16%) |
| 2 | Landruk | Kaski | wildlife | 0.7995 | 3 | Strong offline semantic match to your travel profile (18%); Feature profile matches your preferred trip style (18%) |
| 3 | Kumarwarti Buffer Zone | Nawalpur | wildlife | 0.8105 | 3 | Strong offline semantic match to your travel profile (20%); Feature profile matches your preferred trip style (17%) |
| 4 | Devchuli Hill | Nawalpur | wildlife | 0.7929 | 3 | Strong offline semantic match to your travel profile (18%); Feature profile matches your preferred trip style (18%) |
| 5 | Dhyanakyu Village | Manang | wildlife | 0.7859 | 3 | Strong offline semantic match to your travel profile (18%); Feature profile matches your preferred trip style (18%) |
| 6 | Rupa Lake | Kaski | boating | 0.7414 | 2 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (15%) |
| 7 | Khumai Danda | Kaski | wildlife | 0.7538 | 3 | Strong offline semantic match to your travel profile (19%); Feature profile matches your preferred trip style (18%) |
| 8 | Amaltari Homestay | Nawalpur | wildlife | 0.7378 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (16%) |
| 9 | Khopra Danda | Myagdi | wildlife | 0.7317 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (18%) |
| 10 | Marsyangdi Valley | Lamjung | nature | 0.6922 | 2 | Feature profile matches your preferred trip style (20%); Offline embedding match understands related travel intent (14%) |

### Scenic photography

Viewpoints, sunrise, ridges, and photo-friendly landscapes.

| Rank | Destination | District | Category | Score | Grade | Why |
| ---: | --- | --- | --- | ---: | ---: | --- |
| 1 | Poon Hill | Myagdi | trekking | 0.8036 | 3 | Feature profile matches your preferred trip style (18%); Offline embedding match understands related travel intent (15%) |
| 2 | Sarangkot | Kaski | trekking | 0.7700 | 2 | Feature profile matches your preferred trip style (19%); Offline embedding match understands related travel intent (15%) |
| 3 | Todke Hill | Myagdi | trekking | 0.7561 | 2 | Feature profile matches your preferred trip style (19%); Offline embedding match understands related travel intent (15%) |
| 4 | Mohare Danda | Myagdi | trekking | 0.7533 | 2 | Feature profile matches your preferred trip style (19%); Offline embedding match understands related travel intent (15%) |
| 5 | Bahundanda | Lamjung | trekking | 0.7412 | 3 | Feature profile matches your preferred trip style (20%); Offline embedding match understands related travel intent (15%) |
| 6 | Ajirkot | Gorkha | trekking | 0.7394 | 3 | Feature profile matches your preferred trip style (20%); Offline embedding match understands related travel intent (15%) |
| 7 | Sirandanda | Gorkha | trekking | 0.7390 | 3 | Feature profile matches your preferred trip style (20%); Offline embedding match understands related travel intent (15%) |
| 8 | Kotre | Tanahun | trekking | 0.7383 | 3 | Feature profile matches your preferred trip style (20%); Offline embedding match understands related travel intent (15%) |
| 9 | Gaindakot | Nawalpur | trekking | 0.7374 | 3 | Feature profile matches your preferred trip style (20%); Offline embedding match understands related travel intent (15%) |
| 10 | Manung Kot | Tanahun | trekking | 0.7374 | 2 | Feature profile matches your preferred trip style (20%); Offline embedding match understands related travel intent (16%) |

### Budget relaxation

Quiet low-cost rural stays with soft nature access.

| Rank | Destination | District | Category | Score | Grade | Why |
| ---: | --- | --- | --- | ---: | ---: | --- |
| 1 | Pame | Kaski | boating | 0.7332 | 3 | Feature profile matches your preferred trip style (20%); Offline embedding match understands related travel intent (13%) |
| 2 | Chimkhola | Myagdi | nature | 0.7102 | 3 | Feature profile matches your preferred trip style (20%); Strong offline semantic match to your travel profile (13%) |
| 3 | Suntalabari | Syangja | boating | 0.7192 | 2 | Feature profile matches your preferred trip style (20%); Offline embedding match understands related travel intent (14%) |
| 4 | Tarkughat | Lamjung | nature | 0.7027 | 3 | Feature profile matches your preferred trip style (20%); Strong offline semantic match to your travel profile (12%) |
| 5 | Bihadi | Parbat | village | 0.6634 | 2 | Feature profile matches your preferred trip style (21%); Offline embedding match understands related travel intent (13%) |
| 6 | Singa Hot Spring | Myagdi | village | 0.6984 | 2 | Feature profile matches your preferred trip style (20%); Strong offline semantic match to your travel profile (13%) |
| 7 | Rupa Lake | Kaski | boating | 0.7130 | 2 | Feature profile matches your preferred trip style (20%); Offline embedding match understands related travel intent (13%) |
| 8 | Begkhola | Myagdi | nature | 0.7090 | 3 | Feature profile matches your preferred trip style (20%); Strong offline semantic match to your travel profile (13%) |
| 9 | Rangkhola | Syangja | nature | 0.7032 | 3 | Feature profile matches your preferred trip style (20%); Strong offline semantic match to your travel profile (12%) |
| 10 | Phedikhola | Syangja | nature | 0.7013 | 3 | Feature profile matches your preferred trip style (20%); Strong offline semantic match to your travel profile (12%) |

### Heritage and market culture

Historic towns, local markets, temples, and easy cultural walks.

| Rank | Destination | District | Category | Score | Grade | Why |
| ---: | --- | --- | --- | ---: | ---: | --- |
| 1 | International Mountain Museum | Kaski | cultural | 0.8217 | 3 | Feature profile matches your preferred trip style (18%); Strong offline semantic match to your travel profile (16%) |
| 2 | Marpha | Mustang | pilgrimage | 0.7448 | 2 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (14%) |
| 3 | Tanahunsur | Tanahun | trekking | 0.7411 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (16%) |
| 4 | Khasur Village | Lamjung | village | 0.7328 | 3 | Feature profile matches your preferred trip style (20%); Offline embedding match understands related travel intent (16%) |
| 5 | Gorkha Durbar | Gorkha | cultural | 0.7567 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (15%) |
| 6 | Bhirkot Palace | Syangja | trekking | 0.7389 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (13%) |
| 7 | Baglung Kalika Temple | Baglung | pilgrimage | 0.7204 | 2 | Feature profile matches your preferred trip style (20%); Strong offline semantic match to your travel profile (13%) |
| 8 | Ghandruk | Kaski | trekking | 0.7357 | 3 | Feature profile matches your preferred trip style (19%); Strong offline semantic match to your travel profile (14%) |
| 9 | Bindhyabasini Temple | Kaski | pilgrimage | 0.7356 | 3 | Feature profile matches your preferred trip style (20%); Strong offline semantic match to your travel profile (14%) |
| 10 | Ghyaru | Manang | village | 0.7084 | 3 | Feature profile matches your preferred trip style (19%); Offline embedding match understands related travel intent (15%) |
