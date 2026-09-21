# ==============================================================================
# ASSA Middleware — Monorepo Single Image
# Build all integration CARs, then package into one WSO2 MI runtime.
# ==============================================================================
ARG BASE_IMAGE=wso2/wso2mi:4.6.0
# ---- Stage 1: Build all CAR files ----
FROM maven:3.9-eclipse-temurin-11 AS build

WORKDIR /app

COPY . .

# Build shared module and all integration services
RUN mvn -q -pl shared -am install -DskipTests && \
    mvn -q package -DskipTests

# ---- Stage 2: One WSO2 MI runtime ----
FROM ${BASE_IMAGE}

USER root

# Copy all service CAR files
COPY --from=build /app/shared/target/*.car \
    ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/

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

# Copy JDBC drivers from all services
COPY --from=build /app/integrations/branch-service/deployment/libs/*.jar \
    ${WSO2_SERVER_HOME}/lib/

COPY --from=build /app/integrations/customer-service/deployment/libs/*.jar \
    ${WSO2_SERVER_HOME}/lib/

COPY --from=build /app/integrations/vehicle-service/deployment/libs/*.jar \
    ${WSO2_SERVER_HOME}/lib/

COPY --from=build /app/integrations/vendor-service/deployment/libs/*.jar \
    ${WSO2_SERVER_HOME}/lib/

COPY --from=build /app/integrations/spk-service/deployment/libs/*.jar \
    ${WSO2_SERVER_HOME}/lib/

COPY --from=build /app/integrations/service-request-service/deployment/libs/*.jar \
    ${WSO2_SERVER_HOME}/lib/

# Entrypoint
COPY platform/docker/entrypoint.sh /home/wso2carbon/entrypoint.sh

RUN sed -i 's/\r$//' /home/wso2carbon/entrypoint.sh && \
    chmod +x /home/wso2carbon/entrypoint.sh && \
    chown -R wso2carbon:wso2 \
        /home/wso2carbon/entrypoint.sh \
        ${WSO2_SERVER_HOME}/lib/ \
        ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/

USER wso2carbon

EXPOSE 8290 8253 9164

ENTRYPOINT ["/home/wso2carbon/entrypoint.sh"]