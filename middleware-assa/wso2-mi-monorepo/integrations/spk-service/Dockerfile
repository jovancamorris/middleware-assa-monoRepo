# ==============================================================================
# Dockerfile â€” Integration Service (spk-service)
# Multi-stage: build .car dengan Maven lalu bungkus ke image WSO2 MI.
# BUILD CONTEXT = root monorepo (agar bisa akses parent pom & shared/).
#   docker build -f integrations/spk-service/Dockerfile -t assa/spk-service:1.0.0 .
# ==============================================================================
ARG SERVICE_DIR=integrations/spk-service
ARG BASE_IMAGE=wso2/wso2mi:4.6.0
# ---- Stage 1: build shared + service .car ----
FROM maven:3.9-eclipse-temurin-11 AS build
ARG SERVICE_DIR=integrations/spk-service
WORKDIR /app
COPY . .
# Build shared dulu (di-install ke local repo), lalu service ini jika belum ter-build
RUN if ls /app/${SERVICE_DIR}/target/*.car 1> /dev/null 2>&1 && ls /app/shared/target/*.car 1> /dev/null 2>&1; then \
        echo "Pre-built CAR found for ${SERVICE_DIR}. Skipping maven build."; \
    else \
        mvn -q -pl shared -am install -DskipTests && \
        mvn -q -pl ${SERVICE_DIR} -am package -DskipTests; \
    fi

# ---- Stage 2: runtime ----
FROM ${BASE_IMAGE}
USER root
ARG SERVICE_DIR=integrations/spk-service

# Driver JDBC + CAR service + CAR shared
COPY --from=build /app/${SERVICE_DIR}/deployment/libs/*.jar ${WSO2_SERVER_HOME}/lib/
COPY --from=build /app/${SERVICE_DIR}/target/*.car ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
COPY --from=build /app/shared/target/*.car ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/

# Base config template hasil render + entrypoint bridge (DB forwarder 3307)
COPY platform/docker/entrypoint.sh /home/wso2carbon/entrypoint.sh
RUN sed -i 's/\r$//' /home/wso2carbon/entrypoint.sh && \
    chmod +x /home/wso2carbon/entrypoint.sh && \
    chown -R wso2carbon:wso2 /home/wso2carbon/entrypoint.sh \
        ${WSO2_SERVER_HOME}/lib/*.jar \
        ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/*.car

USER wso2carbon
EXPOSE 8290 8253 9164
ENTRYPOINT ["/home/wso2carbon/entrypoint.sh"]
