# Shared Connectors

Folder ini menampung connector pihak ketiga yang dipakai lintas service (mis. HTTP connector, SAP, dll).

Saat ini connector HTTP (`mi-connector-http`) dideklarasikan sebagai dependency Maven di masing-masing service `pom.xml`, sehingga tidak perlu file JAR di sini. Simpan connector kustom / hasil unduhan manual di folder ini bila diperlukan, lalu referensikan dari service terkait.

> Driver JDBC (mis. `mariadb-java-client`) tetap di-manage sebagai Maven dependency dan disalin ke image lewat Dockerfile masing-masing service.
