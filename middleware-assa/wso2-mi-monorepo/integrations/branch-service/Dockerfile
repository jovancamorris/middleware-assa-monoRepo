# ==============================================================================
# Dockerfile — Integration Service (branch-service)
# Multi-stage: build .car dengan Maven lalu bungkus ke image WSO2 MI.
# BUILD CONTEXT = root monorepo (agar bisa akses parent pom & shared/).
#   docker build -f integrations/branch-service/Dockerfile -t assa/branch-service:1.0.0 .
# ==============================================================================
ARG BASE_IMAGE=wso2/wso2mi:4.6.0
# ---- Stage 1: build shared + service .car ----
FROM maven:3.9-eclipse-temurin-11 AS build
WORKDIR /app
COPY . .
# Build shared dulu (di-install ke local repo), lalu service ini
RUN mvn -q -pl shared -am install -DskipTests && \
    mvn -q -pl integrations/branch-service -am package -DskipTests

# ---- Stage 2: runtime ----
FROM ${BASE_IMAGE}
USER root
ARG SERVICE_DIR=integrations/branch-service

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
