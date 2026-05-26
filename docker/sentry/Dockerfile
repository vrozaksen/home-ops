# renovate: datasource=docker depName=ghcr.io/getsentry/sentry
ARG SENTRY_VERSION=26.5.0
FROM ghcr.io/getsentry/sentry:${SENTRY_VERSION}

USER root

# sentry-auth-oidc community plugin (Jeffail fork — most maintained)
# renovate: datasource=pypi depName=sentry-auth-oidc
ARG SENTRY_AUTH_OIDC_VERSION=4.1.0

RUN /usr/local/bin/pip install --no-cache-dir \
        sentry-auth-oidc==${SENTRY_AUTH_OIDC_VERSION}

USER sentry
