ARG BASE_IMAGE
FROM ${BASE_IMAGE}
COPY CompositeApps/vendor-service_*.car ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
COPY CompositeApps/shared-artifacts_*.car ${WSO2_SERVER_HOME}/repository/deployment/server/carbonapps/
COPY resources/wso2carbon.jks ${WSO2_SERVER_HOME}/repository/resources/security/wso2carbon.jks
COPY resources/client-truststore.jks ${WSO2_SERVER_HOME}/repository/resources/security/client-truststore.jks
COPY libs/*.jar ${WSO2_SERVER_HOME}/lib/
COPY entrypoint.sh /home/wso2carbon/entrypoint.sh
RUN sed -i 's/\r$//' /home/wso2carbon/entrypoint.sh && \
    chmod +x /home/wso2carbon/entrypoint.sh && \
    chown wso2carbon:wso2 /home/wso2carbon/entrypoint.sh
USER wso2carbon
EXPOSE 8290 8253 9164
ENTRYPOINT ["/home/wso2carbon/entrypoint.sh"]
