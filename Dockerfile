FROM varnish:stable

RUN apt-get update && \
  apt-get install gettext-base && \
  apt-get clean

ENV BACKEND_HOST="localhost"
ENV BACKEND_PORT="80"

# Primary and secondary defaults are set in start.sh

# ENV BACKEND_PRIMARY_HOST=$BACKEND_HOST
# ENV BACKEND_PRIMARY_PORT=$BACKEND_PORT

# ENV BACKEND_SECONDARY_HOST=$BACKEND_HOST
# ENV BACKEND_SECONDARY_PORT=$BACKEND_PORT

ENV HEADER_POWERED_BY="HLS Cache v0.1"

COPY config.vcl /etc/varnish/template.vcl
COPY start.sh /etc/varnish/start.sh

RUN ["chmod", "+x", "/etc/varnish/start.sh"]

# Remove default entrypoint
ENTRYPOINT []

# Replace ENV before actually starting
CMD /etc/varnish/start.sh;
