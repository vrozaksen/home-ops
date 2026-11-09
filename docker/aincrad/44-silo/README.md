# Silo: funkcje do włączenia

Wszystko poniżej ustawia się w panelu admina Silo (silo.vzkn.eu → Admin), nie w
compose. Kolejność to proponowana kolejność włączania. Nazwy w `kodzie` to klucze
ustawień albo nazwy z dokumentacji upstreamu (`docs/architecture/` w
Silo-Server/silo-server), żeby łatwo było je znaleźć.

## 1. Sprzęt i odtwarzanie

- **Transkodowanie QSV (VA-API).** `/dev/dri` jest już podany do kontenera, z grupą 18.
  W ustawieniach Playback wybierz Intel QSV. UHD730 robi tonemapping HDR→SDR,
  tak jak w Emby.
- **Backupy** (Admin → Backups). Cel `default`, bo trafiają do
  `/mnt/blaze/appdata/silo/backups`, czyli na dataset ze snapshotami sanoid.
  Włącz nocne. Backup to `pg_dump` plus pliki, których nie da się pobrać
  ponownie, z możliwością przywrócenia wybranych części. Okładek i trickplay
  nie obejmuje, bo te da się odtworzyć.

## 2. Znaczniki: intro, napisy końcowe, rozdziały

- **Wykrywanie intro i napisów końcowych** (`markers.detect_intros`,
  `markers.detect_credits`). To codzienne zadanie „Detect markers on this server”.
  Porównuje audio odcinków serialu i znajduje wspólne intro, a w filmach szuka
  napisów końcowych. Klienci pokazują wtedy „Pomiń intro” i „Następny odcinek”.
  Włącza się per biblioteka.
- **Plugin TheIntroDB** (`silo-plugin-markers-theintrodb`). Pobiera gotowe
  znaczniki z sieci, więc nie trzeba liczyć wszystkiego lokalnie.
  `markers.online_storage` ustaw na zapis w Silo, NIE „Save to library”, bo
  biblioteka jest zamontowana tylko do odczytu.
- **Miniatury rozdziałów** (`chapter-images`). To obrazki w liście rozdziałów.

## 3. Trickplay

Miniatury, które pokazują się nad paskiem przewijania po najechaniu albo
przeciągnięciu. Silo generuje je per plik jako arkusze JPEG. Domyślnie jest to
wyłączone, a włącza się per biblioteka (`trickplay_enabled`). Przy pierwszym
przebiegu dużo liczy, bo dekoduje klatki z całej biblioteki, i sporo zajmuje.
Leży w `cache/silo-meta`, więc nie trafia do snapshotów.

## 4. Watch Together

Wspólne oglądanie na odległość. Ktoś zakłada pokój i zaprasza innych. Pokój
najpierw jest w lobby i czeka, aż wszyscy będą gotowi, a potem odtwarzanie
startuje u wszystkich naraz. Pauza, przewijanie i wznowienie u jednej osoby
dzieją się u wszystkich. Stan pokoju trzyma Postgres, a zdarzenia rozchodzą się
przez Redis, który już działa (`silo-redis`). Nic nie trzeba stawiać. Działa w
aplikacji webowej Silo i w natywnych klientach Silo. Przez API zgodności z
Jellyfinem nie działa, bo SyncPlay nie jest obsługiwany, więc Findroid i
Infuse go nie mają.

## 5. AI (LiteLLM, klucz `silo`)

Klucz: `kubectl -n ai get secret litellm-key-silo -o jsonpath='{.data.api-key}' | base64 -d`.
Dostawca: custom OpenAI-compatible, base URL `https://litellm.vzkn.eu/v1`.

- **Tłumaczenie napisów i metadanych.** Model tekstowy `deepseek/deepseek-chat`.
  Tłumaczy napisy na żądanie, a metadane (np. opisy po polsku) w chwili, gdy
  ktoś otwiera tytuł.
- **Transkrypcja (Whisper).** Model mowy `groq/whisper-large-v3-turbo`. Tworzy
  napisy z audio, gdy żadnych nie ma. Działa na żądanie, nie w tle dla całej
  biblioteki. Audio idzie do Groq.
- **Rekomendacje i wyszukiwanie semantyczne** (`recommendations.enabled`).
  Model embeddingów `embed` (bge-m3, wielojęzyczny). Każdy tytuł dostaje
  wektor, a z historii oglądania powstaje profil gustu. Na tej podstawie Silo
  buduje wiersze „dla Ciebie”, „oglądane razem z” oraz sezonowe propozycje
  (`seasonal_themed`, listy MDBList dopasowane do świąt). Wyszukiwanie zaczyna
  też rozumieć opisy typu „film o skoku na bank”.
  **Uwaga:** model embeddingów blokuje się przy pierwszym przebiegu
  (`recommendations.embedding_lock`). Zmiana później oznacza reset i liczenie
  wszystkiego od nowa.

## 6. Prośby o media i *arry

- **Prośby o media.** Użytkownik prosi o film albo serial z Discover, a admin
  zatwierdza ręcznie albo automatycznie według polityki. Prośba idzie do
  Sonarr/Radarr i kończy się, gdy plik jest w bibliotece. Reguły kierowania
  po gatunku, języku i tym, czy to anime, wysyłają anime do `sonarr-anime` i
  `radarr-anime`. Anime Silo wykrywa sam (TMDB plus lista Kometa Anime-IDs).
  Dodanie tytułu do watchlisty może też automatycznie złożyć prośbę
  (`requests.watchlist_auto_request`).
  URL-e: `https://sonarr.vzkn.eu`, `https://sonarr-anime.vzkn.eu`,
  `https://radarr.vzkn.eu`, `https://radarr-anime.vzkn.eu`.
- **Autoscan** (`silo-plugin-autoscan-arr`). Czyta historię *arrów i od razu
  skanuje tylko zaimportowane albo przemianowane pliki, zamiast całej
  biblioteki. Przepisanie ścieżki: `/data/media` → `/mnt/media`. Połączenie z
  *arrem można użyć ponownie z ustawień próśb.
- **Seerr zostaje**, dopóki Emby jest głównym serwerem.

## 7. Logowanie i użytkownicy

- **Kanidm (OIDC)** (`silo-plugin-auth-oidc`). Klienta OAuth2 w Kanidm dodaje
  się w home-ops.
- **Zaproszenia.** Kod wielokrotnego użytku albo osobiste zaproszenie z
  ustawionym z góry dostępem do bibliotek.
- **Profile domowe.** Każdy profil ma własny stan oglądania, dostęp do
  bibliotek i kontrolę rodzicielską.

## 8. Reszta

- **Synchronizacja z Emby.** Zajmuje się nią CrossWatch (`46-crosswatch`),
  nie Silo.
- **Simkl / MDBList** (pluginy watch-provider). Synchronizują historię,
  oceny i porzucone seriale, a MDBList dodaje też oceny zbiorcze.
- **Kolekcje.** Gotowe szablony, tzw. starter packs, i kolekcje
  synchronizowane z list. Box sety filmów z kolekcji TMDB
  (`box_sets_enabled` per biblioteka).
- **Nakładki na plakaty.** Odznaki 4K, Dolby Vision i oceny oraz status
  oglądania. Ustawia się per profil.
- **Powiadomienia.** Dostępność nowych odcinków i filmów: skrzynka, web push,
  webhooki, Discord.
- **Synchronizacja napisów.** Dopasowuje timing pobranych napisów do audio
  pliku, np. przy przyspieszeniu PAL 25 fps albo dodatkowym logo na początku.
- **Pobieranie offline.** Wymaga osobnego volume `download-artifacts`,
  jeszcze go nie ma.
- **Metryki.** `SILO_METRICS_LISTEN` plus scrape z klastra, jeszcze tego nie ma.
