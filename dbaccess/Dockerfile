FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Instala utilitários, drivers ODBC, pacotes de compatibilidade TOTVS e libaio1 (Vital para Oracle Client)
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
    libaio1 \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 2. Adiciona o repositório oficial da Microsoft e instala o driver msodbcsql18
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql18 && \
    rm -rf /var/lib/apt/lists/*

# 3. Baixa e instala o Oracle Instant Client 21.3 Basic Lite na pasta mapeada pelo template
WORKDIR /opt/oracle
RUN wget https://download.oracle.com/otn_software/linux/instantclient/213000/instantclient-basiclite-linux.x64-21.3.0.0.0.zip \
    && unzip instantclient-basiclite-linux.x64-21.3.0.0.0.zip \
    && rm instantclient-basiclite-linux.x64-21.3.0.0.0.zip \
    && sh -c "echo /opt/oracle/instantclient_21_3 > /etc/ld.so.conf.d/oracle-instantclient.conf" \
    && ldconfig

# 4. Cria a estrutura oficial garantindo a existência do diretório multi/
RUN mkdir -p /opt/totvs/dbaccess/multi
WORKDIR /opt/totvs/dbaccess/multi

# 5. Copia o arquivo compactado para um local temporário
COPY dbaccess_linux_x64.tar.gz /tmp/dbaccess.tar.gz

# 6. Extração Inteligente: Extrai tudo em /tmp e move o conteúdo da pasta interna para o local correto
RUN mkdir -p /tmp/extracao && \
    tar -xzf /tmp/dbaccess.tar.gz -C /tmp/extracao/ && \
    # Move os arquivos da pasta que a TOTVS criou (independente do nome dela) para dentro de /multi/
    cp -R /tmp/extracao/*/* /opt/totvs/dbaccess/multi/ 2>/dev/null || cp -R /tmp/extracao/* /opt/totvs/dbaccess/multi/ && \
    rm -rf /tmp/dbaccess.tar.gz /tmp/extracao

# 7. Força permissões de execução no binário e diretórios internos de forma segura
RUN chmod +x /opt/totvs/dbaccess/multi/dbaccess64 || chmod +x /opt/totvs/dbaccess/multi/multi/dbaccess64 2>/dev/null
RUN chmod -R 755 /opt/totvs/dbaccess/multi/

# 8. Injeta os templates e o script de inicialização do ecossistema DevOps
COPY dbaccess.ini.tmpl /opt/totvs/dbaccess/multi/
COPY entrypoint.sh /usr/local/bin/

# Variaveis de ambiente cruciais para o runtime da OCI localizar as dependências
ENV ORACLE_HOME=/opt/oracle/instantclient_21_3
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient_21_3:$LD_LIBRARY_PATH

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 7890

ENTRYPOINT ["entrypoint.sh"]