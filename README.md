HLS Cache Varnish Docker Image
===

Dead simple docker image presenting a pre-configured varnish cache to put in front of an HLS server.

## Configuration

## Usage

```yml
  varnish:
    container_name: varnish
    build: ./docker-varnish-hls-cache
    ports:
      - "8080:80"
    environment:
      BACKEND_HOST: encoder
      BACKEND_PORT: 80
```