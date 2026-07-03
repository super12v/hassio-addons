ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.19
FROM ${BUILD_FROM}

# Install Python, Patroni with Raft, psycopg2, and multiple PostgreSQL versions
RUN apk add --no-cache \
      python3 \
      py3-pip \
      py3-cryptography \
      py3-yaml \
      py3-psycopg2 \
      postgresql14 \
      postgresql14-client \
      postgresql15 \
      postgresql15-client \
      postgresql16 \
      postgresql16-client \
      su-exec \
    && pip3 install --no-cache-dir --break-system-packages \
      patroni[raft]==4.1.3 \
      psycopg2-binary \
    && rm -rf /root/.cache /tmp/*

# Create data directory for Raft state and PG data dir
RUN mkdir -p /data/raft /data/pgdata && chown -R postgres:postgres /data/pgdata /data/raft

COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
