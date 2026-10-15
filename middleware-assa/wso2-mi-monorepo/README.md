# WSO2 MI Monorepo — ASSA Middleware

Monorepo multi-service untuk platform integrasi ASSA berbasis **WSO2 Micro Integrator**. Setiap domain integrasi berdiri sebagai service terpisah (punya `.car` & image Docker sendiri), sementara logika lintas-domain (auth, logging, error, idempotency, retry, DB) dipusatkan di modul `shared/`.

Struktur ini menggantikan project tunggal `middleware-assa` yang lama (satu `.car` untuk semua domain).

> **Created By**: Nobi Sumariga

> **Updated By**: Jovan & Rifqi

---

## Struktur Direktori

```text
wso2-mi-monorepo/
├── .github/workflows/deploy-integrations.yml   # CI/CD (build + docker + deploy)
├── shared/                                      # Artefak reusable (di-package jadi 1 CAR)
│   ├── src/main/wso2mi/artifacts/sequences/     # AuthGuard, LogRequest, ErrorResponse,
│   │                                            # Idempotency, ResolveBaseUrl, SafeApiCall,
│   │                                            # ApiCallErrorHandler, DbRecord*, Pagination,
│   │                                            # HealthCheck, RetryWorker, FaultHandler
│   ├── connectors/                              # Connector pihak ketiga (opsional)
│   └── pom.xml
├── integrations/                                # SEMUA service integrasi
│   ├── branch-service/                          # Branch domain (SAP Core)
│   ├── customer-service/                        # Customer domain (SAP Core)
│   ├── vehicle-service/                         # Vehicle / Vehicle Atlas (ASSA Ext)
│   ├── vendor-service/                          # Vendor Master Data (VMD) → FTP
│   ├── spk-service/                             # SPK Duelist → FTP
│   └── service-request-service/                 # Service Request fan-out (ATLAS + Ext) + Worker
│       └── (tiap service: src/, Dockerfile, pom.xml)
├── platform/                                    # Infrastruktur & base config
│   ├── docker/deployment.toml.j2                # Base config template WSO2 MI (Jinja2)
│   ├── docker/entrypoint.sh                     # Entrypoint bridge (DB forwarder 3307)
│   └── k8s/base-deployment.yaml                 # Base K8s manifest (Deployment + Service)
├── scripts/db/init_mariadb_schema.sql           # Skema DB (dipakai docker-compose)
├── docker-compose.yml                           # Jalankan SEMUA service sekaligus (lokal)
├── pom.xml                                      # Root/Parent POM (aggregator)
└── .gitignore
```

---

## Pemetaan Domain (dari `middleware-assa` lama)

| Service | API | Domain Sequence | Endpoint | Backend |
|---|---|---|---|---|
| `branch-service` | `BranchAPI`, `BranchHealthAPI`, `BranchReadinessAPI` | `BranchGetByCreateDateSeq` | `SapCoreDynamicEndpoint` | SAP Core |
| `customer-service` | `CustomerAPI`, `CustomerHealthAPI`, `CustomerReadinessAPI` | `CustomerGetByCreateDateSeq` | `SapCoreDynamicEndpoint` | SAP Core |
| `vehicle-service` | `VehicleAPI`, `VehicleHealthAPI`, `VehicleReadinessAPI` | `VehicleGetByLicensePlateSeq` | `ExtServiceDynamicEndpoint` | ASSA Ext / Vehicle Atlas |
| `vendor-service` | `VendorHealthAPI`, `VendorReadinessAPI` (+ VMD API menyusul) | (VMD → XML → FTP) | (FTP VFS) | SAP via FTP |
| `spk-service` | `SpkHealthAPI`, `SpkReadinessAPI` (+ SPK API menyusul) | (SPK Duelist → XML → FTP) | (FTP VFS) | SAP via FTP |
| `service-request-service` | `WorkerAPI`, `ServiceRequestHealthAPI`, `ServiceRequestReadinessAPI` (+ SR API menyusul) | fan-out ATLAS + Ext | (ATLAS/Ext POST) | ATLAS + ASSA Ext |

> Semua sequence lintas-domain (Auth, Logging, Error, Idempotency, Retry, DB, Pagination, Health, Worker) berada di `shared/` dan dirujuk tiap service via `<sequence key="..."/>`.
>
> Service `vendor`, `spk`, dan `service-request` saat ini berisi kerangka (Health + config). API/sequence spesifiknya diimplementasi mengikuti guide di `docs/` (`GUIDE_VENDOR_CREATE_XML_FTP_V2.md`, `GUIDE_SPK_DUELIST_XML_FTP_V2.md`, `GUIDE_SR.md`).

---

## Build

Prasyarat: JDK 11, Maven 3.9+, Docker.

### Build seluruh monorepo (shared + semua service)
```powershell
mvn clean install
```
`shared` di-build lebih dulu (di-install ke local repo), lalu tiap service menghasilkan `.car` di `integrations/<service>/target/`.

### Build satu service saja (beserta shared)
```powershell
mvn -pl shared -am install
mvn -pl integrations/branch-service -am package
```

---

## Menjalankan Lokal (Docker Compose)

Menjalankan MariaDB + seluruh service sekaligus:
```powershell
docker compose up --build
```

Pemetaan port host → service (semua kontainer internal `8290`):
| Service | Port host |
|---|---|
| branch-service | 8290 |
| customer-service | 8291 |
| vehicle-service | 8292 |
| vendor-service | 8293 |
| spk-service | 8294 |
| service-request-service | 8295 |
| MariaDB | 3308 → 3306 |

Uji health, contoh:
```powershell
curl http://localhost:8290/health/branch
curl http://localhost:8290/readiness/branch
```

---

## Deploy ke Kubernetes

Gunakan base manifest `platform/k8s/base-deployment.yaml` (Deployment + Service, dengan probe service-specific `/health/<service>` & `/readiness/<service>`). Render per service lalu apply:
```powershell
# contoh untuk branch-service
(Get-Content platform/k8s/base-deployment.yaml) `
  -replace '__SERVICE_NAME__','branch-service' `
  -replace '__IMAGE__','<REGISTRY>/branch-service:1.0.0' | kubectl apply -f -
```
Untuk konfigurasi lengkap (ConfigMap, Secret, Ingress, HPA, egress, DB), lihat `docs/GUIDE_DOCKER_KUBERNETES.md`.

---

## CI/CD

`.github/workflows/deploy-integrations.yml` menjalankan:
1. **build** — `mvn clean install` seluruh monorepo (validasi shared + service).
2. **docker** — build & push image per service (matrix, paralel) ke `${REGISTRY}`.
3. **deploy** (opsional, `vars.ENABLE_DEPLOY == 'true'`) — render `base-deployment.yaml` & `kubectl apply` per service.

Secret/vars yang dibutuhkan: `REGISTRY` (vars), `REGISTRY_USERNAME`/`REGISTRY_PASSWORD` (secrets), `KUBECONFIG_B64` (secret, untuk deploy).

---

## Konfigurasi & Environment

- **Base config**: `platform/docker/deployment.toml.j2` (template Jinja2 dengan placeholder per environment).
- **Per-service config**: `integrations/<service>/src/main/wso2mi/resources/conf/config.properties`.
- **Base URL & DB** dapat di-override via environment variable (`SAP_CORE_BASE_URL`, `ASSA_EXT_BASE_URL`, `DB_HOST`, `DB_PORT`) — resolusi 4-layer ditangani `ResolveBaseUrlSeq`.
- **DB forwarder**: `entrypoint.sh` mem-forward `127.0.0.1:3307 → ${DB_HOST}:${DB_PORT}`, jadi `config.properties`/`deployment.toml` tetap menunjuk `localhost:3307` tanpa perlu diubah antar-environment.

> **Keamanan**: pindahkan token, API key, dan password DB dari `config.properties` ke Secret / WSO2 Secure Vault untuk produksi. Jangan commit kredensial nyata.

---

## Referensi
- `docs/SOFTWARE_ARCHITECTURE_DOCUMENT.md` — SAD platform.
- `docs/GUIDE_DOCKER_KUBERNETES.md` — deploy Docker/K8s + egress & domain backend.
- `docs/GUIDE_VENDOR_CREATE_XML_FTP_V2.md`, `GUIDE_SPK_DUELIST_XML_FTP_V2.md`, `GUIDE_SR.md` — spesifikasi fitur.
