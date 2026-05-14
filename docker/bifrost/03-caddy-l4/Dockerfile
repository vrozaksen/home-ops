# renovate: datasource=docker depName=caddy
ARG CADDY_VERSION=2.11.2

FROM docker.io/caddy:${CADDY_VERSION}-builder AS builder
RUN xcaddy build \
    --with github.com/mholt/caddy-l4 \
    --with github.com/caddy-dns/ovh

FROM docker.io/caddy:${CADDY_VERSION}
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
