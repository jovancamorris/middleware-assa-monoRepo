FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docs/ /usr/share/nginx/html/docs/
COPY platform/docker/nginx-entrypoint.sh /usr/local/bin/nginx-entrypoint.sh

RUN chmod 755 /usr/local/bin/nginx-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/nginx-entrypoint.sh"]
