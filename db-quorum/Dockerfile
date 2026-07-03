ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm
FROM ${BUILD_FROM}

# Install Redis (for sentinel) and curl (for MariaDB health checks)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      redis-sentinel \
      mariadb-client \
      curl \
      netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Create data directories
RUN mkdir -p /data/sentinel /data/arbiter

COPY run.sh /
COPY mariadb-arbiter.sh /
RUN chmod a+x /run.sh /mariadb-arbiter.sh

CMD ["/run.sh"]
