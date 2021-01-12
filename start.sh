#!/bin/bash

# Yeah.. By default, Varnish will round robin between 1 servers...
export BACKEND_PRIMARY_HOST="${BACKEND_PRIMARY_HOST:-$BACKEND_HOST}";
export BACKEND_PRIMARY_PORT="${BACKEND_PRIMARY_PORT:-$BACKEND_PORT}";

export BACKEND_SECONDARY_HOST="${BACKEND_SECONDARY_HOST:-$BACKEND_HOST}";
export BACKEND_SECONDARY_PORT="${BACKEND_SECONDARY_PORT:-$BACKEND_PORT}";

envsubst < "template.vcl" > "default.vcl";
cat default.vcl;

docker-varnish-entrypoint;