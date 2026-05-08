FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# 1) Update and install base packages (including dpkg, sed)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
       dpkg \
       sed \
       curl \
       wget \
       gnupg \
       ca-certificates \
       apt-transport-https \
       software-properties-common \
       lsb-release \
       bind9 \
       bind9-utils \
       bind9-dnsutils \
       procps \
       net-tools \
       iproute2 \
       openssl \
       perl \
       libnet-ssleay-perl \
       libauthen-pam-perl \
       libio-pty-perl \
       libpam-runtime \
       unzip && \
    rm -rf /var/lib/apt/lists/*

# 2) Download Webmin .deb
RUN wget -O /tmp/webmin-current.deb https://www.webmin.com/download/deb/webmin-current.deb

# 3) Install Webmin with dpkg, then fix dependencies with apt
RUN apt-get update && \
    dpkg -i /tmp/webmin-current.deb || true && \
    apt-get -f install -y && \
    rm -f /tmp/webmin-current.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/named /var/webmin /etc/bind /etc/bind/zones /var/cache/bind /var/lib/bind

COPY config/named.conf /etc/bind/named.conf
COPY config/named.conf.options /etc/bind/named.conf.options
COPY config/named.conf.local /etc/bind/named.conf.local
COPY config/db.home.test /var/cache/bind/db.home.test

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 53/tcp 53/udp 10000/tcp

VOLUME ["/etc/bind", "/var/cache/bind", "/var/lib/bind"]

ENTRYPOINT ["/entrypoint.sh"]
