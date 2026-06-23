FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=pt_BR.UTF-8
ENV LANGUAGE=pt_BR:pt
ENV LC_ALL=pt_BR.UTF-8

# Adicionado 'dmidecode' para leitura de UUID/Hardware exigido pelo License Server
RUN apt-get update && apt-get install -y \
    libc6 \
    libtinfo5 \
    libuuid1 \
    libnet-ifconfig-wrapper-perl \
    netcat-openbsd \
    openjdk-11-jre-headless \
    locales \
    dmidecode \
    && echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# HACK: Cria um comando systemctl falso que sempre diz "OK" para enganar o instalador da TOTVS
RUN echo '#!/bin/bash\nexit 0' > /usr/local/bin/systemctl && chmod +x /usr/local/bin/systemctl

WORKDIR /tmp/totvs_installer
COPY license.tar.gz ./
RUN tar -xzf license.tar.gz && rm license.tar.gz
RUN chmod +x install && ./install 2
RUN rm /usr/local/bin/systemctl

WORKDIR /
RUN rm -rf /tmp/totvs_installer

WORKDIR /totvs/totvslicensevirtual
COPY entrypoint.sh ./
RUN chmod +x entrypoint.sh

# Portas mapeadas: 5555 (License), 2235 (Service), 4000 (Log), 8020 (Web Monitor)
EXPOSE 5555 2235 4000 8020

ENTRYPOINT ["./entrypoint.sh"]