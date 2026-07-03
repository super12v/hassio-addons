ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm
FROM ${BUILD_FROM}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      redis-sentinel \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data/sentinel

COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
