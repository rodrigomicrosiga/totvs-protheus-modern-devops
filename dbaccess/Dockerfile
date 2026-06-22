FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Instala utilitários, drivers ODBC e pacotes de compatibilidade TOTVS
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg2 \
    gettext-base \
    netcat-openbsd \
    unixodbc \
    unixodbc-dev \
    odbc-postgresql \
    libc6 \
    libtinfo5 \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# 2. Adiciona o repositório oficial da Microsoft e instala o driver msodbcsql18
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql18 && \
    rm -rf /var/lib/apt/lists/*

# 3. Cria a estrutura oficial garantindo a existência do diretório multi/
RUN mkdir -p /opt/totvs/dbaccess/multi
WORKDIR /opt/totvs/dbaccess/multi

# 4. Copia o arquivo compactado para um local temporário
COPY dbaccess_linux_x64.tar.gz /tmp/dbaccess.tar.gz

# 5. Extração Inteligente: Extrai tudo em /tmp e move o conteúdo da pasta interna para o local correto
RUN mkdir -p /tmp/extracao && \
    tar -xzf /tmp/dbaccess.tar.gz -C /tmp/extracao/ && \
    # Move os arquivos da pasta que a TOTVS criou (independente do nome dela) para dentro de /multi/
    cp -R /tmp/extracao/*/* /opt/totvs/dbaccess/multi/ 2>/dev/null || cp -R /tmp/extracao/* /opt/totvs/dbaccess/multi/ && \
    rm -rf /tmp/dbaccess.tar.gz /tmp/extracao

# 6. Força permissões de execução no binário e diretórios internos de forma segura
RUN chmod +x /opt/totvs/dbaccess/multi/dbaccess64 || chmod +x /opt/totvs/dbaccess/multi/multi/dbaccess64 2>/dev/null
RUN chmod -R 755 /opt/totvs/dbaccess/multi/

# 7. Injeta os templates e o script de inicialização do ecossistema DevOps
COPY dbaccess.ini.tmpl /opt/totvs/dbaccess/multi/
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 7890

ENTRYPOINT ["entrypoint.sh"]