# Panduan Drop File ke Server Dev (`https://devmiddleware.assa.id`)
Folder Target Server: `/var/www/devwso2` (atau `/var/www/devmiddleware`)

---

## 1. Ringkasan Perubahan Terbaru
1. **Fitur Login Hit LDAP / REST API Dihapus**:
   - Plugin custom userstore `AssaRestUserStoreManager` (`assa-rest-userstore-1.0.0.jar`) telah **dihapus**.
   - WSO2 API Manager kembali menggunakan **Default Native User Store** (`UniqueIDJDBCUserStoreManager`).
2. **Kredensial Super Admin WSO2 APIM Diperbarui**:
   - **Username**: `admindev`
   - **Password**: `4554r3nt*2023`
   - Dikonfigurasi otomatis via `[super_admin]` dan `[apim.key_manager]` di `deployment.toml`.
3. **Skrip Otomasi Diperbarui**:
   - `import-all-apis.sh`, `apply-backend-token-policy.py`, dan `render-registry-secrets.sh` kini otomatis menggunakan `admindev` / `4554r3nt*2023`.

---

## 2. Daftar File yang PERLU di-Drop ke Server

File-file berikut di folder `notes/folder-server-baru` **siap langsung di-copy / di-drop ke folder server**:

| Nama File | Keterangan & Perbaikan yang Disertakan |
|---|---|
| **`docker-compose.yml`** | ✅ Menggunakan image terbaru **1.0.9**.<br>✅ Menghapus mount & dependensi `assa-rest-userstore-1.0.0.jar`.<br>✅ Mengonfigurasi `[super_admin]` dengan username `admindev` dan password `4554r3nt*2023` serta `create_admin_account = true`.<br>✅ Mengonfigurasi `APIM_HOSTNAME=devmiddleware.assa.id`, `APIM_PROXY_PORT=443`, dan Virtual Host Gateway otomatis. |
| **`nginx.conf`** | ✅ Buffer size diperbesar (`128k`/`256k`) agar tidak error 502 Bad Gateway saat SSO/OAuth2 APIM.<br>✅ Menghapus port 9443 pada redirect HTTP/OAuth APIM.<br>✅ Menambahkan rute `/logincontext` dan `/api/am/` untuk portal APIM.<br>✅ Menambahkan rute proxy ke `apim_gateway` (port 8243) untuk versioned APIs (`/api/*/1.0.0/*`) sehingga Try Out di Publisher langsung berfungsi. |
| **`import-all-apis.sh`** | ✅ Skrip otomatisasi sekali klik untuk registrasi client DCR, generate token OAuth2, dan **Publish 7 API** ke APIM Publisher & DevPortal dengan kredensial baru `admindev` / `4554r3nt*2023`. |
| **`apply-backend-token-policy.py`** | ✅ Otomatis injeksi backend policy token X-API-Key ke seluruh API dengan kredensial `admindev` / `4554r3nt*2023`. |
| **`render-registry-secrets.sh`** | ✅ Skrip render kredensial database MariaDB ke WSO2 MI Registry dan Service Catalog dengan kredensial `admindev`. |

*(Catatan: File `assa-rest-userstore-1.0.0.jar` sudah **TIDAK ADA** dan jika masih ada file lama tersebut di folder server, aman untuk dihapus).*

---

## 3. File yang TIDAK PERLU / JANGAN Langsung Timpa

| Nama File | Alasan |
|---|---|
| **`.env`** *(JANGAN TIMPA SELURUHNYA)* | ⚠️ **PENTING**: Server sudah memiliki `.env` dengan password MariaDB, kredensial FTP, dan token SAP eksisting.<br>👉 **Solusi**: Cukup periksa `.env` di server dan pastikan variabel APIM berikut disesuaikan:<br>```env<br>APIM_ADMIN_USERNAME=admindev<br>APIM_ADMIN_PASSWORD="4554r3nt*2023"<br>APIM_HOSTNAME=devmiddleware.assa.id<br>APIM_PROXY_PORT=443<br>``` |
| **`Dockerfile.nginx`** | Tidak perlu di-drop jika container Nginx menggunakan image standar `nginx:alpine` via volume mount `nginx.conf`. |

---

## 4. Langkah Eksekusi di Server Setelah File di-Drop

Buka terminal SSH (PuTTY / Terminal) di server, lalu jalankan:

### Langkah A: Masuk ke folder server
```bash
cd /var/www/devwso2
# (atau cd /var/www/devmiddleware sesuai lokasi stack server Anda)
```

### Langkah B: Hapus file JAR lama (jika ada di server)
```bash
rm -f assa-rest-userstore-1.0.0.jar
```

### Langkah C: Beri izin eksekusi pada skrip
```bash
chmod +x render-registry-secrets.sh import-all-apis.sh apply-backend-token-policy.py
```

### Langkah D: Pastikan variabel `.env` di server sudah sesuai
Buka `.env` di server atau jalankan:
```bash
# Tambahkan / perbarui kredensial APIM di .env jika belum ada:
grep -q "APIM_ADMIN_USERNAME" .env && sed -i 's/^APIM_ADMIN_USERNAME=.*/APIM_ADMIN_USERNAME=admindev/' .env || echo 'APIM_ADMIN_USERNAME=admindev' >> .env
grep -q "APIM_ADMIN_PASSWORD" .env && sed -i 's/^APIM_ADMIN_PASSWORD=.*/APIM_ADMIN_PASSWORD="4554r3nt*2023"/' .env || echo 'APIM_ADMIN_PASSWORD="4554r3nt*2023"' >> .env
```

### Langkah E: Reset Database APIM (Sangat Disarankan agar Admin Baru Aktif Bersih)
Jika sebelumnya APIM sudah pernah jalan dengan database H2 lama, reset volume database APIM agar kredensial `admindev` / `4554r3nt*2023` dibuat segar dari `deployment.toml`:
```bash
docker compose stop api-manager
# Hapus volume database APIM lama:
docker volume rm $(docker compose config --volumes | grep -E "apim_repository_(data|database)" | tr '\n' ' ') 2>/dev/null || true
```
*(Catatan: Ini HANYA mereset data internal APIM, TIDAK mengganggu database MariaDB Anda).*

### Langkah F: Jalankan / Restart Stack Docker
```bash
docker compose up -d --force-recreate
```

### Langkah G: Pantau Status Hingga Sehat
```bash
docker compose ps
docker compose logs -f api-manager
```
*(Tunggu ~40-60 detik sampai WSO2 APIM selesai booting dan berstatus healthy)*

### Langkah H: Import & Publish Semua 7 Service ke APIM
Setelah container `middleware-wso2-apim` berstatus **healthy**, jalankan:
```bash
./import-all-apis.sh
```

---

## 5. Kredensial & URL Pengujian

### Kredensial Login WSO2 APIM:
- **Username**: `admindev`
- **Password**: `4554r3nt*2023`

### URL Pengujian:
1. **API Manager Publisher**:  
   `https://devmiddleware.assa.id/publisher`  
   *(Login menggunakan `admindev` / `4554r3nt*2023`)*
2. **API Manager Developer Portal**:  
   `https://devmiddleware.assa.id/devportal`  
   *(Login menggunakan `admindev` / `4554r3nt*2023`)*
3. **WSO2 Carbon Management Console**:  
   `https://devmiddleware.assa.id/carbon`  
   *(Login menggunakan `admindev` / `4554r3nt*2023`)*
4. **Swagger UI**:  
   `https://devmiddleware.assa.id/docs`
5. **Health Check API**:  
   `https://devmiddleware.assa.id/health`
