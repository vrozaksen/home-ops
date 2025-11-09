# Plan Migracji z Crunchy Postgres do CloudNative-PG

**Data utworzenia:** 7 listopada 2025
**Status:** Planowanie

## 🔍 Analiza Obecnego Stanu

### Aplikacje Aktywne (14 aplikacji używających Crunchy Postgres):

#### AI (2):
- `litellm`
- `open-webui`

#### Self-hosted (3):
- `atuin`
- `reactive-resume`
- `miniflux`

#### Security (1):
- `authentik` ⚠️ **KRYTYCZNA**

#### Observability (1):
- `grafana` ⚠️ **KRYTYCZNA**

#### Media (2):
- `jellyseerr`
- `jellystat`

#### Downloads - ARR Stack (4):
- `sonarr`
- `radarr`
- `prowlarr`
- `bazarr`

#### Sentry (1):
- `sentry`

### Aplikacje Zarchiwizowane (6 aplikacji):
- `vikunja` ✅ Kandydat do migracji
- `paperless` ✅ Kandydat do migracji (duża baza!)
- `mealie` ✅ Kandydat do migracji
- `zipline` ❌ Niski priorytet
- `netbox` ⚠️ Złożona konfiguracja
- `outline` ⚠️ Może być stary chart

---

## 🔄 Główne Różnice między Crunchy i CNPG

| Aspekt | Crunchy Postgres | CloudNative-PG |
|--------|-----------------|----------------|
| **Nazwa klastra** | `${APP}` | `postgres-${APP}` |
| **Secret użytkownika** | `${APP}-pguser-${APP}` | `postgres-${APP}-app` |
| **Klucz hasła w secret** | `password` | `password` (bez zmian) |
| **Klucz URI** | `uri` | `uri` (bez zmian) |
| **Service endpoint** | `${APP}-pgbouncer` | `postgres-${APP}-rw` |
| **PgBouncer** | Wbudowany | Opcjonalny external |
| **Backup** | pgBackRest (częste incr.) | Barman Cloud (daily) |
| **Postgres wersja** | 17 | 17-18 (konfigurowalny) |
| **Repliki** | 3 (domyślnie) | 3 (domyślnie) |
| **Storage domyślny** | 5Gi | 2Gi |
| **CPU domyślny** | brak limitu | 25m request |
| **Memory domyślny** | brak limitu | 256Mi/512Mi |
| **Max connections** | 500 | 100 |

---

## 📋 Plan Migracji Krok po Kroku

### FAZA 0: Przygotowania (PRE-MIGRATION)

#### 1. Backup wszystkich aktywnych baz ✅
```bash
# Sprawdzić status backupów w MinIO
# Crunchy automatycznie tworzy backupy do MinIO
kubectl get cronjobs -n database | grep repo

# Zrobić manual full backup przed migracją dla każdej aplikacji
kubectl annotate postgrescluster <APP> -n <NAMESPACE> \
  postgres-operator.crunchydata.com/pgbackrest-backup="$(date +%Y%m%d-%H%M%S)"
```

#### 2. Dokumentacja połączeń aplikacji
- Zweryfikować które aplikacje używają PgBouncer
- Które mają direct connection do Postgres
- Sprawdzić ENV variables w każdej aplikacji

#### 3. Weryfikacja External Secrets
```bash
# Sprawdzić czy secret cloudnative-pg istnieje
kubectl get externalsecret cloudnative-pg -n database

# Bitwarden secret: 'cloudnative-pg' powinien zawierać:
# - POSTGRES_SUPER_USER
# - POSTGRES_SUPER_PASS
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
```

---

### FAZA 1: Infrastruktura

#### 1. Upewnić się że CNPG operator działa
```bash
kubectl get pods -n database -l app.kubernetes.io/name=cloudnative-pg
kubectl logs -n database -l app.kubernetes.io/name=cloudnative-pg
```

#### 2. Sprawdzić plugin barman-cloud
```bash
kubectl get pods -n database -l app=plugin-barman-cloud
```

#### 3. Zweryfikować dostęp do MinIO/S3
```bash
# Test połączenia do bucket'a postgresql
kubectl run -it --rm test-s3 --image=amazon/aws-cli --restart=Never -- \
  s3 ls s3://postgresql/ --endpoint-url=https://s3.vzkn.eu
```

---

### FAZA 2: Strategia Migracji

**OPCJA A: Migracja "na czysto" (ZALECANA)**
- Dump z Crunchy → Import do CNPG
- Kontrolowany downtime (~5-15 min per app)
- Czysta konfiguracja CNPG od początku
- **Wybrana metoda dla wszystkich aplikacji**

**OPCJA B: Migracja przez restore z backup**
- Wykorzystanie Crunchy backup → CNPG restore
- Trudniejsza konwersja formatów (pgBackRest → Barman)
- **NIE ZALECANA** - różne narzędzia backup

---

### FAZA 3: Kolejność Migracji

#### Grupa 1 - Niski priorytet (DEV/TEST)
**Cel:** Zdobycie doświadczenia, testowanie procedury

1. **atuin** - mała baza, niski ruch, osobiste użycie
2. **miniflux** - RSS reader, można stracić status przeczytanych
3. **reactive-resume** - CV builder, mało danych

**Downtime akceptowalny:** 30-60 min

---

#### Grupa 2 - Media (średni priorytet)
**Cel:** Aplikacje z większym ruchem, ale nie krytyczne

4. **jellystat** - tylko statystyki, można odtworzyć
5. **jellyseerr** - requesty mediów, akceptowalny downtime

**Downtime akceptowalny:** 15-30 min

---

#### Grupa 3 - ARR Stack (wyższy priorytet)
**Cel:** Aplikacje powiązane, migrować razem w oknie maintenance

6. **prowlarr** - najpierw indexer (inne zależą od niego)
7. **bazarr** - napisy, najmniej krytyczny z ARR
8. **radarr** - filmy
9. **sonarr** - seriale

**Downtime akceptowalny:** 15 min per app, ~1h całość
**Zalecenie:** Weekend, późny wieczór

---

#### Grupa 4 - AI/ML (średni-wysoki priorytet)

10. **litellm** - proxy LLM, używany aktywnie
11. **open-webui** - UI dla LLM

**Downtime akceptowalny:** 10-15 min

---

#### Grupa 5 - Krytyczne (ostatnie, największa ostrożność)
**Cel:** Po zdobyciu doświadczenia z poprzednimi

12. **grafana** - dashboardy i alerty, monitoring ⚠️
13. **authentik** - SSO/Identity Provider ⚠️⚠️ **NAJWAŻNIEJSZE**
14. **sentry** - error tracking

**Downtime akceptowalny:** <10 min
**Zalecenie:**
- Grafana: weekend, rano (żeby monitorować przez dzień)
- Authentik: **weekend, z backup planem**
- Sentry: po Authentik, żeby mieć error tracking

**💡 NOTA:** Synchronous replication (`CNPG_SYNC_METHOD: any`) będzie **domyślnie włączona** dla WSZYSTKICH aplikacji - minimalne overhead (~1-2ms), zero data loss na failover.

---

### FAZA 4: Procedura Migracji dla Pojedynczej Aplikacji

#### Szablon dla aplikacji: `<APP>`

```bash
# ==============================================================================
# MIGRACJA: <APP>
# Namespace: <NAMESPACE>
# Data: <DATA>
# ==============================================================================

# --- KROK 1: PRE-MIGRATION BACKUP ---
echo "==> Tworzenie backup przed migracją..."

# Manual backup w Crunchy
kubectl annotate postgrescluster <APP> -n <NAMESPACE> \
  postgres-operator.crunchydata.com/pgbackrest-backup="$(date +%Y%m%d-%H%M%S)"

# Poczekaj na zakończenie backup jobu
kubectl wait --for=condition=complete job -l postgres-operator.crunchydata.com/cluster=<APP> \
  -n <NAMESPACE> --timeout=30m

# --- KROK 2: SCALE DOWN APLIKACJI ---
echo "==> Zatrzymywanie aplikacji..."
kubectl scale deployment <APP> -n <NAMESPACE> --replicas=0

# Poczekaj na zatrzymanie
kubectl wait --for=delete pod -l app.kubernetes.io/name=<APP> -n <NAMESPACE> --timeout=5m

# --- KROK 3: DUMP BAZY DANYCH ---
echo "==> Dump bazy danych..."

# Znajdź pod Postgres
POSTGRES_POD=$(kubectl get pods -n <NAMESPACE> -l postgres-operator.crunchydata.com/cluster=<APP>,postgres-operator.crunchydata.com/role=master -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POSTGRES_POD"

# Dump do pliku
kubectl exec -n <NAMESPACE> $POSTGRES_POD -- \
  pg_dump -U <APP> -d <APP> -F c -f /tmp/<APP>.dump

# Skopiuj dump lokalnie
kubectl cp <NAMESPACE>/$POSTGRES_POD:/tmp/<APP>.dump ./<APP>.dump

# Backup dump do bezpiecznej lokacji
cp ./<APP>.dump ./backups/<APP>-$(date +%Y%m%d-%H%M%S).dump

# --- KROK 4: AKTUALIZACJA KONFIGURACJI ---
echo "==> Aktualizacja konfiguracji Kubernetes..."

# Edytuj: kubernetes/apps/<NAMESPACE>/<APP>/ks.yaml
# ZMIANY:
# 1. components:
#    BYŁO: - ../../../components/postgres
#    JEST: - ../../../components/cnpg/restore  # ✅ PERMANENTNY!
#
# 2. dependsOn:
#    BYŁO: - name: crunchy-postgres-operator
#    JEST: - name: cloudnative-pg
#          - name: plugin-barman-cloud
#
# 3. healthCheckExprs:
#    BYŁO: - apiVersion: postgres-operator.crunchydata.com/v1beta1
#          kind: PostgresCluster
#          failed: status.conditions.filter(e, e.type == 'ProxyAvailable').all(e, e.status == 'False')
#          current: status.conditions.filter(e, e.type == 'ProxyAvailable').all(e, e.status == 'True')
#    JEST: - apiVersion: postgresql.cnpg.io/v1
#          kind: Cluster
#          failed: status.conditions.filter(e, e.type == 'Ready').all(e, e.status == 'False')
#          current: status.conditions.filter(e, e.type == 'Ready').all(e, e.status == 'True')
#
# 4. postBuild.substitute (dodać):
#    APP: <APP>
#    CNPG_SIZE: 5Gi  # dostosować do rozmiaru bazy
#    CNPG_REQUESTS_CPU: 100m  # dostosować
#    CNPG_LIMITS_MEMORY: 512Mi  # dostosować
#
# UWAGA: Używamy 'restore' nie 'initdb' bo migrujemy ISTNIEJĄCE bazy!
#        Po migracji ZOSTAW 'restore' na stałe dla disaster recovery!

# Edytuj: kubernetes/apps/<NAMESPACE>/<APP>/helmrelease.yaml
# ZMIANY w ENV:
# 1. Secret name:
#    BYŁO: <APP>-pguser-<APP>
#    JEST: postgres-<APP>-app
#
# 2. Database host/service (jeśli używane):
#    BYŁO: <APP>-pgbouncer.<NAMESPACE>.svc
#    JEST: postgres-<APP>-rw.<NAMESPACE>.svc
#
# 3. Klucz hasła (bez zmian): password
# 4. Klucz URI (bez zmian): uri

# --- KROK 5: COMMIT I DEPLOY ---
echo "==> Commit zmian..."
git add kubernetes/apps/<NAMESPACE>/<APP>/
git commit -m "migrate(<APP>): Crunchy Postgres → CloudNative-PG"
git push

# --- KROK 6: WAIT FOR CNPG CLUSTER ---
echo "==> Czekam na CNPG cluster..."
kubectl wait --for=condition=Ready cluster/postgres-<APP> -n <NAMESPACE> --timeout=10m

# Sprawdź status
kubectl get cluster postgres-<APP> -n <NAMESPACE>
kubectl get pods -n <NAMESPACE> -l cnpg.io/cluster=postgres-<APP>

# --- KROK 7: RESTORE DUMP ---
echo "==> Restore danych..."

# Znajdź primary pod CNPG
CNPG_POD=$(kubectl get pods -n <NAMESPACE> -l cnpg.io/cluster=postgres-<APP>,role=primary -o jsonpath='{.items[0].metadata.name}')
echo "CNPG Pod: $CNPG_POD"

# Skopiuj dump do poda
kubectl cp ./<APP>.dump <NAMESPACE>/$CNPG_POD:/tmp/<APP>.dump

# Restore dump
kubectl exec -n <NAMESPACE> $CNPG_POD -- \
  pg_restore -U <APP> -d <APP> -c -F c /tmp/<APP>.dump

# Cleanup dump w podzie
kubectl exec -n <NAMESPACE> $CNPG_POD -- rm /tmp/<APP>.dump

# --- KROK 8: VERIFY DATABASE ---
echo "==> Weryfikacja bazy danych..."

# Sprawdź tabele
kubectl exec -n <NAMESPACE> $CNPG_POD -- \
  psql -U <APP> -d <APP> -c "\dt"

# Sprawdź przykładowe dane (dostosować query)
kubectl exec -n <NAMESPACE> $CNPG_POD -- \
  psql -U <APP> -d <APP> -c "SELECT COUNT(*) FROM <main_table>;"

# --- KROK 9: SCALE UP APLIKACJI ---
echo "==> Uruchamianie aplikacji..."
kubectl scale deployment <APP> -n <NAMESPACE> --replicas=1

# Poczekaj na ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=<APP> -n <NAMESPACE> --timeout=5m

# --- KROK 10: WERYFIKACJA APLIKACJI ---
echo "==> Weryfikacja aplikacji..."

# Sprawdź logi
kubectl logs -n <NAMESPACE> -l app.kubernetes.io/name=<APP> --tail=100

# Sprawdź czy aplikacja działa (curl do healthcheck endpoint)
kubectl run -it --rm test-curl --image=curlimages/curl --restart=Never -- \
  curl -v http://<APP>.<NAMESPACE>.svc/<healthcheck-path>

# --- KROK 11: POST-MIGRATION MONITORING ---
echo "==> Monitoring przez 24h..."
echo "1. Sprawdź logi aplikacji przez pierwsze 30 min"
echo "2. Test funkcjonalności krytycznych"
echo "3. Monitor resource usage w Grafana"
echo "4. Sprawdź czy backup CNPG działa (następnego dnia)"

# --- KROK 12: CLEANUP (PO 24-48H) ---
echo "==> Cleanup po pomyślnej migracji..."

# Usuń stary PostgresCluster (Crunchy)
# kubectl delete postgrescluster <APP> -n <NAMESPACE>

# Usuń stare PVC (OPCJONALNIE, zachować backup przez tydzień)
# kubectl get pvc -n <NAMESPACE> | grep <APP>-postgres
# kubectl delete pvc <APP>-postgres-<instance>-xxxxx -n <NAMESPACE>

echo "==> MIGRACJA ZAKOŃCZONA"
```

---

### FAZA 5: Szczegółowe Zmiany w Konfiguracji

#### Przykład: prowlarr

**PRZED (Crunchy):**
```yaml
# kubernetes/apps/downloads/prowlarr/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app prowlarr
spec:
  components:
    - ../../../components/postgres
  dependsOn:
    - name: crunchy-postgres-operator
      namespace: database
    - name: external-secrets-store
      namespace: external-secrets
  healthCheckExprs:
    - apiVersion: postgres-operator.crunchydata.com/v1beta1
      kind: PostgresCluster
      failed: status.conditions.filter(e, e.type == 'ProxyAvailable').all(e, e.status == 'False')
      current: status.conditions.filter(e, e.type == 'ProxyAvailable').all(e, e.status == 'True')
  interval: 1h
  path: ./kubernetes/apps/downloads/prowlarr
  postBuild:
    substitute:
      APP: *app
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  wait: false
```

**PO (CNPG):**
```yaml
# kubernetes/apps/downloads/prowlarr/ks.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app prowlarr
spec:
  components:
    - ../../../components/cnpg/backup
  dependsOn:
    - name: cloudnative-pg
      namespace: database
    - name: external-secrets-store
      namespace: external-secrets
  healthCheckExprs:
    - apiVersion: postgresql.cnpg.io/v1
      kind: Cluster
      failed: status.conditions.filter(e, e.type == 'Ready').all(e, e.status == 'False')
      current: status.conditions.filter(e, e.type == 'Ready').all(e, e.status == 'True')
  interval: 1h
  path: ./kubernetes/apps/downloads/prowlarr
  postBuild:
    substitute:
      APP: *app
      CNPG_SIZE: 2Gi
      CNPG_REQUESTS_CPU: 100m
      CNPG_LIMITS_MEMORY: 512Mi
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  wait: false
```

**HelmRelease ENV:**
```yaml
# PRZED (Crunchy)
env:
  - name: POSTGRES__HOST
    value: prowlarr-pgbouncer.downloads.svc
  - name: POSTGRES__PASSWORD
    valueFrom:
      secretKeyRef:
        name: prowlarr-pguser-prowlarr
        key: password

# PO (CNPG) - opcja 1: URI
env:
  - name: POSTGRES__URI
    valueFrom:
      secretKeyRef:
        name: postgres-prowlarr-app
        key: uri

# PO (CNPG) - opcja 2: individual fields
env:
  - name: POSTGRES__HOST
    valueFrom:
      secretKeyRef:
        name: postgres-prowlarr-app
        key: host
  - name: POSTGRES__PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-prowlarr-app
        key: password
```

---

### FAZA 6: Resource Sizing Guidelines

#### Zalecenia per aplikacja:

| Aplikacja | Baza Size | CPU Request | Memory Limit | Max Conn | Uzasadnienie |
|-----------|-----------|-------------|--------------|----------|--------------|
| atuin | 2Gi | 25m | 256Mi | 50 | Mała baza, osobiste |
| miniflux | 2Gi | 50m | 512Mi | 100 | RSS, średni ruch |
| reactive-resume | 2Gi | 25m | 256Mi | 50 | Mało danych |
| jellystat | 2Gi | 100m | 512Mi | 100 | Statystyki, analytics |
| jellyseerr | 2Gi | 100m | 512Mi | 100 | Requesty |
| prowlarr | 2Gi | 100m | 512Mi | 100 | Indexer, API calls |
| bazarr | 2Gi | 100m | 512Mi | 100 | Napisy |
| radarr | 3Gi | 200m | 1Gi | 150 | Duża biblioteka |
| sonarr | 3Gi | 200m | 1Gi | 150 | Duża biblioteka |
| litellm | 2Gi | 100m | 512Mi | 100 | Proxy LLM |
| open-webui | 3Gi | 200m | 1Gi | 150 | UI LLM, historia |
| grafana | 5Gi | 200m | 1Gi | 200 | Dashboardy, alerty |
| authentik | 5Gi | 500m | 2Gi | 300 | SSO, krytyczna |
| sentry | 5Gi | 300m | 1Gi | 200 | Error tracking |

**💡 Wszystkie używają sync replication (domyślnie):**
- `CNPG_SYNC_METHOD: any, CNPG_SYNC_NUMBER: '1', CNPG_SYNC_DURABILITY: preferred`
- Minimalne overhead, near-zero data loss, self-healing

---

### FAZA 7: Migracja Aplikacji Zarchiwizowanych

#### Decyzja per aplikacja:

**DO MIGRACJI (teraz):**
1. ✅ **mealie** - recipes, popularne, prawdopodobne odarchiwizowanie
2. ✅ **vikunja** - TODO manager, może wrócić
3. ✅ **paperless** - dokumenty, DUŻA BAZA!, ważne dane

**DO MIGRACJI (przy odarchiwizowaniu):**
4. ⚠️ **netbox** - złożona, zmigrować tylko jeśli pewność odarchiwizowania
5. ⚠️ **outline** - wiki, może wymagać update chart'u
6. ❌ **zipline** - niski priorytet, likely deprecated

#### Procedura dla zarchiwizowanych:

```bash
# 1. Backup istniejącej bazy Crunchy (jeśli jeszcze działa)
# 2. Zmigruj konfigurację (ks.yaml, helmrelease.yaml)
# 3. DODAJ komentarz w .archive/*/ks.yaml:
#    # MIGRATED TO CNPG - READY TO RESTORE FROM CRUNCHY BACKUP
# 4. Przy odarchiwizowaniu:
#    - Jeśli backup istnieje: użyj components/cnpg/restore
#    - Jeśli brak backup: fresh start
```

---

### FAZA 8: Cleanup po Pełnej Migracji

Po pomyślnej migracji WSZYSTKICH aplikacji (14 aktywnych):

```bash
# 1. Usuń wszystkie stare PostgresCluster (Crunchy)
kubectl get postgrescluster --all-namespaces
# Usuń każdy ręcznie po weryfikacji

# 2. Usuń Crunchy operator
# Edytuj: kubernetes/apps/database/kustomization.yaml
# Usuń linię: - ./crunchy-postgres/ks.yaml

# 3. Commit
git add kubernetes/apps/database/kustomization.yaml
git commit -m "chore(database): remove Crunchy Postgres operator after full migration"
git push

# 4. Usuń katalog components/postgres (opcjonalnie)
# Zachować przez 1-2 tygodnie dla rollback

# 5. Update dokumentacji
# Zaktualizuj README.md w komponencie CNPG
```

---

## ⚠️ Ryzyka i Mitigation

### Ryzyko 1: Authentik down = brak dostępu do wszystkiego
**Mitigation:**
- Migruj w weekend z zapasowym planem
- Miej gotowy rollback (Crunchy cluster backup)
- Test login PRZED i PO migracji
- Backup Authentik secrets osobno
- Synchronous replication **domyślnie włączona** dla wszystkich aplikacji (minimal overhead, zero data loss)

### Ryzyko 2: Strata danych podczas dump/restore
**Mitigation:**
- Zawsze manual backup przed migracją
- Test dump przed delete Crunchy
- Weryfikacja count(*) po restore
- Zachować Crunchy cluster 48h po migracji

### Ryzyko 3: Aplikacja nie działa z CNPG
**Mitigation:**
- Test na dev aplikacji najpierw (atuin)
- Sprawdź logi aplikacji
- Rollback: skaluj down, przywróć Crunchy, skaluj up

### Ryzyko 4: Storage za mały (2Gi domyślne)
**Mitigation:**
- Sprawdź rozmiar obecnych baz:
  ```bash
  kubectl exec -n <NS> <POD> -- \
    psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database;"
  ```
- Ustaw CNPG_SIZE na 2x obecny rozmiar minimum

### Ryzyko 5: Max connections za niski (100 vs 500)
**Mitigation:**
- Monitoruj connection count przed migracją
- Zwiększ CNPG_MAX_CONNECTIONS jeśli potrzeba (ale idle DBs zwykle ok z 100)
- ℹ️ PgBouncer nie jest potrzebny - failover automatyczny przez `-rw` service

### Ryzyko 6: Backup nie działa w CNPG
**Mitigation:**
- Test backup/restore przed migracją produkcji
- Sprawdź ScheduledBackup status:
  ```bash
  kubectl get scheduledbackup --all-namespaces
  ```
- Verify backups w MinIO bucket

---

## 📝 Checklist Master (całość projektu)

### Pre-Migration
- [ ] Backup wszystkich 14 baz danych Crunchy
- [ ] Zweryfikować CNPG operator ready
- [ ] Zweryfikować barman-cloud plugin ready
- [ ] Zweryfikować External Secrets CNPG
- [ ] Test dump/restore na dev aplikacji
- [ ] Przygotować rollback plan

### Migration Progress

#### Grupa 1 - DEV/TEST
- [ ] atuin (namespace: self-hosted)
- [ ] miniflux (namespace: self-hosted)
- [ ] reactive-resume (namespace: self-hosted)

#### Grupa 2 - Media
- [ ] jellystat (namespace: media)
- [ ] jellyseerr (namespace: media)

#### Grupa 3 - ARR Stack
- [ ] prowlarr (namespace: downloads)
- [ ] bazarr (namespace: downloads)
- [ ] radarr (namespace: downloads)
- [ ] sonarr (namespace: downloads)

#### Grupa 4 - AI
- [ ] litellm (namespace: ai)
- [ ] open-webui (namespace: ai)

#### Grupa 5 - Critical
- [ ] grafana (namespace: observability) ⚠️
- [ ] authentik (namespace: security) ⚠️⚠️
- [ ] sentry (namespace: sentry) ⚠️

### Post-Migration
- [ ] Monitor wszystkich aplikacji 24-48h
- [ ] Verify backups CNPG działają
- [ ] Test restore z CNPG backup (sample app)
- [ ] Cleanup stare PostgresCluster Crunchy
- [ ] Cleanup stare PVC
- [ ] Remove Crunchy operator
- [ ] Update dokumentacji

### Archived Apps (optional)
- [ ] mealie
- [ ] vikunja
- [ ] paperless

---

## 📊 Tracking Progress

| # | Aplikacja | Namespace | Status | Data | Downtime | Notes |
|---|-----------|-----------|--------|------|----------|-------|
| 1 | atuin | self-hosted | ⏳ Pending | - | - | - |
| 2 | miniflux | self-hosted | ⏳ Pending | - | - | - |
| 3 | reactive-resume | self-hosted | ⏳ Pending | - | - | - |
| 4 | jellystat | media | ⏳ Pending | - | - | - |
| 5 | jellyseerr | media | ⏳ Pending | - | - | - |
| 6 | prowlarr | downloads | ⏳ Pending | - | - | - |
| 7 | bazarr | downloads | ⏳ Pending | - | - | - |
| 8 | radarr | downloads | ⏳ Pending | - | - | - |
| 9 | sonarr | downloads | ⏳ Pending | - | - | - |
| 10 | litellm | ai | ⏳ Pending | - | - | - |
| 11 | open-webui | ai | ⏳ Pending | - | - | - |
| 12 | grafana | observability | ⏳ Pending | - | - | - |
| 13 | authentik | security | ⏳ Pending | - | - | - |
| 14 | sentry | sentry | ⏳ Pending | - | - | - |

**Status legend:**
- ⏳ Pending - Nie rozpoczęto
- 🔄 In Progress - W trakcie migracji
- ✅ Completed - Zakończona pomyślnie
- ❌ Failed - Niepowodzenie (wymaga rollback)
- 🔙 Rolled Back - Wycofano zmiany

---

## 🎯 Podsumowanie

### Oszacowany czas:
- **Przygotowania:** 1-2h
- **Migracja pojedynczej aplikacji:** 15-30 min
- **Całość (14 aplikacji):** ~8-12h roboczych (rozłożone na 3-5 dni)

### Zalecenia:
1. ✅ Zacznij od `atuin` (najmniejsze ryzyko)
2. ✅ Migruj max 2-3 aplikacje dziennie
3. ✅ Testuj dokładnie po każdej migracji (24h monitoring)
4. ✅ Zostaw `authentik` i `grafana` na koniec
5. ✅ Weekend dla krytycznych aplikacji
6. ✅ Zachowaj Crunchy clusters 48h po migracji
7. ✅ Backup przed każdą migracją

### Success Criteria:
- ✅ Wszystkie aplikacje działają poprawnie
- ✅ Dane zmigrowane bez strat
- ✅ Backups CNPG działają
- ✅ Resource usage w normie
- ✅ Brak błędów w logach aplikacji
- ✅ Performance porównywalny lub lepszy
- ✅ Crunchy operator usunięty

### Rollback Plan:
Jeśli migracja nie powiedzie się:
1. Scale down aplikację
2. Przywróć stary PostgresCluster (Crunchy)
3. Restore z Crunchy backup
4. Przywróć stare referencje w ks.yaml/helmrelease.yaml
5. Scale up aplikację
6. Debug problem przed kolejną próbą

---

## 📚 Referencje

- **CNPG Docs:** https://cloudnative-pg.io/
- **Crunchy Docs:** https://access.crunchydata.com/documentation/postgres-operator/
- **Migration Guide:** `/home/vrozaksen/git/home-ops/kubernetes/components/cnpg/README.md`
- **Resource Config:** `/home/vrozaksen/git/home-ops/docs/cnpg-resource-configs.yaml`

---

**Ostatnia aktualizacja:** 7 listopada 2025
**Autor:** Migration Team
**Status:** Ready for Execution
