# ==============================================================================
# ESTÁGIO 1: Builder
# ==============================================================================
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    tar openjdk-11-jre-headless libnet-ifconfig-wrapper-perl && rm -rf /var/lib/apt/lists/*

RUN echo '#!/bin/bash\nexit 0' > /usr/local/bin/systemctl && chmod +x /usr/local/bin/systemctl

WORKDIR /tmp/totvs_installer
COPY ./license.tar.gz .
RUN tar -xzf license.tar.gz && rm license.tar.gz && chmod +x install && ./install 2

# ==============================================================================
# ESTÁGIO 2: Runner
# ==============================================================================
FROM ubuntu:22.04 AS runner
LABEL maintainer="Rodrigo dos Santos Brandão <rodrigomicrosiga>"
LABEL version="3.7.1"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=pt_BR.UTF-8
ENV LANGUAGE=pt_BR:pt
ENV LC_ALL=pt_BR.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    libc6 libtinfo5 libuuid1 libnet-ifconfig-wrapper-perl netcat-openbsd \
    openjdk-11-jre-headless locales dmidecode \
    && echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /totvs/totvslicensevirtual /totvs/totvslicensevirtual

WORKDIR /totvs/totvslicensevirtual
COPY ./entrypoint.sh ./
RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]