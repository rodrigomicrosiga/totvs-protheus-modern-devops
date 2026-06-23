FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=pt_BR.UTF-8
ENV LANGUAGE=pt_BR:pt
ENV LC_ALL=pt_BR.UTF-8

# 1. Instala dependências nativas do AppServer Linux, utilitários e o pacote locales
RUN apt-get update && apt-get install -y \
    libc6 \
    libtinfo5 \
    libuuid1 \
    netcat-openbsd \
    unzip \
    locales \
    && echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# 2. Define o diretório de runtime do AppServer dentro do container
WORKDIR /totvs/protheus/bin/appserver

# 3. Importa e extrai os binários estáticos diretamente da sua estrutura local
COPY ./protheus/bin/appserver/appserver.tar.gz /tmp/
RUN tar -xzf /tmp/appserver.tar.gz -C /totvs/protheus/bin/appserver/ && rm /tmp/appserver.tar.gz

# 4. Importa, extrai e posiciona o WebApp (SmartClient HTML) no mesmo nível do binário
COPY ./protheus/bin/smartclient/webapp.tar.gz /tmp/
RUN tar -xzf /tmp/webapp.tar.gz -C /totvs/protheus/bin/appserver/ && rm /tmp/webapp.tar.gz

# 5. Mapeia o entrypoint inteligente do ecossistema
COPY ./appserver/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Porta do barramento TCP e WebApp configurada no .ini
EXPOSE 1234

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]