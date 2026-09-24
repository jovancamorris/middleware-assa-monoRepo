# Build a single WSO2 MI image from the existing integrations project.
ARG BASE_IMAGE=wso2/wso2mi:4.6.0

FROM maven:3.9-eclipse-temurin-11 AS build
WORKDIR /app
COPY . .
RUN mvn -q clean package -DskipTests

FROM ${BASE_IMAGE}
USER root

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

COPY --from=build /app/integrations/branch-service/deployment/docker/libs/*.jar ${WSO2_SERVER_HOME}/lib/
COPY --from=build /app/integrations/customer-service/deployment/docker/libs/*.jar ${WSO2_SERVER_HOME}/lib/
COPY --from=build /app/integrations/vehicle-service/deployment/docker/libs/*.jar ${WSO2_SERVER_HOME}/lib/
COPY --from=build /app/integrations/vendor-service/deployment/docker/libs/*.jar ${WSO2_SERVER_HOME}/lib/
COPY --from=build /app/integrations/spk-service/deployment/docker/libs/*.jar ${WSO2_SERVER_HOME}/lib/
COPY --from=build /app/integrations/service-request-service/deployment/docker/libs/*.jar ${WSO2_SERVER_HOME}/lib/
COPY --from=build /app/platform/docker/resources/*.jks ${WSO2_SERVER_HOME}/repository/resources/security/
COPY platform/docker/entrypoint.sh /home/wso2carbon/entrypoint.sh

RUN sed -i 's/\r$//' /home/wso2carbon/entrypoint.sh && \
    chmod +x /home/wso2carbon/entrypoint.sh && \
    chown -R wso2carbon:wso2 /home/wso2carbon/entrypoint.sh \
        ${WSO2_SERVER_HOME}/lib/ \
        ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/

USER wso2carbon
EXPOSE 8290 8253 9164
ENTRYPOINT ["/home/wso2carbon/entrypoint.sh"]
