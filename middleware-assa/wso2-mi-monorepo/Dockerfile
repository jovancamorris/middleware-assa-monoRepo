# Multi-target Dockerfile for WSO2 MI Monorepo
# Supports both unified single image (all-in-one) and per-service microservice containers.
ARG BASE_IMAGE=wso2/wso2mi:4.6.0

FROM maven:3.9-eclipse-temurin-11 AS build
WORKDIR /app
COPY . .
RUN mvn -q clean package -DskipTests && \
    mkdir -p /app/libs && \
    curl -fsSL -o /app/libs/mariadb-java-client-3.3.3.jar https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.3.3/mariadb-java-client-3.3.3.jar

# Base WSO2 MI runtime with common shared components
FROM ${BASE_IMAGE} AS base-runtime
USER root

# Selalu salin shared artifacts CAR ke runtime
COPY --from=build /app/shared/target/*.car \
    ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/

# Salin JDBC Driver MariaDB ke library WSO2 MI runtime
COPY --from=build /app/libs/*.jar ${WSO2_SERVER_HOME}/lib/

# Salin SSL certificates, entrypoint forwarder & skema SQL
COPY --from=build /app/platform/docker/resources/*.jks ${WSO2_SERVER_HOME}/repository/resources/security/
COPY platform/docker/entrypoint.sh /home/wso2carbon/entrypoint.sh
COPY --from=build /app/scripts/db/init_mariadb_schema.sql /docker-entrypoint-initdb.d/01_init.sql
# Salin dokumentasi & kontrak OpenAPI 3.0 ke dalam image container
COPY --from=build /app/docs /app/docs

RUN sed -i 's/\r$//' /home/wso2carbon/entrypoint.sh && \
    chmod +x /home/wso2carbon/entrypoint.sh && \
    chown -R wso2carbon:wso2 /home/wso2carbon/entrypoint.sh \
        ${WSO2_SERVER_HOME}/lib/ \
        ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/

USER wso2carbon
EXPOSE 8290 8253 9164
ENTRYPOINT ["/home/wso2carbon/entrypoint.sh"]

# ----------------------------------------------------
# Microservice Targets (Per Service untuk Local Dev)
# ----------------------------------------------------
FROM base-runtime AS branch-service
USER root
COPY --from=build /app/integrations/branch-service/target/*.car ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
USER wso2carbon

FROM base-runtime AS customer-service
USER root
COPY --from=build /app/integrations/customer-service/target/*.car ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
USER wso2carbon

FROM base-runtime AS vehicle-service
USER root
COPY --from=build /app/integrations/vehicle-service/target/*.car ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
USER wso2carbon

FROM base-runtime AS vendor-service
USER root
COPY --from=build /app/integrations/vendor-service/target/*.car ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
USER wso2carbon

FROM base-runtime AS spk-service
USER root
COPY --from=build /app/integrations/spk-service/target/*.car ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
USER wso2carbon

FROM base-runtime AS service-request-service
USER root
COPY --from=build /app/integrations/service-request-service/target/*.car ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
USER wso2carbon

# ----------------------------------------------------
# Unified Target (Default jika build tanpa --target)
# ----------------------------------------------------
FROM base-runtime AS all-in-one
USER root
COPY --from=build /app/integrations/branch-service/target/*.car \
    ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
COPY --from=build /app/integrations/customer-service/target/*.car \
    ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
COPY --from=build /app/integrations/vehicle-service/target/*.car \
    ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
COPY --from=build /app/integrations/vendor-service/target/*.car \
    ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
COPY --from=build /app/integrations/spk-service/target/*.car \
    ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
COPY --from=build /app/integrations/service-request-service/target/*.car \
    ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
USER wso2carbon
