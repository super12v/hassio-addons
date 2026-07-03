ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm
FROM ${BUILD_FROM}

# Install corosync-qnetd and openssh for the pvecm setup handshake
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      corosync-qnetd \
      openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Create directories for SSH and qnetd state
RUN mkdir -p /data/qnetd /run/sshd

COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
