# ==============================================================================
# ESTÁGIO 1: Builder (Download de Drivers e Descompactação Multi)
# ==============================================================================
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends wget unzip tar && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/build

# Baixa o Instant Client Oracle e puxa o DbAccess local
RUN wget https://download.oracle.com/otn_software/linux/instantclient/213000/instantclient-basiclite-linux.x64-21.3.0.0.0.zip && \
    unzip instantclient-basiclite-linux.x64-21.3.0.0.0.zip

COPY ./dbaccess/dbaccess_linux_x64.tar.gz .
RUN mkdir -p dbaccess_extracao /tmp/out_dbaccess && \
    tar -xzf dbaccess_linux_x64.tar.gz -C dbaccess_extracao/ && \
    (cp -R dbaccess_extracao/*/* /tmp/out_dbaccess/ 2>/dev/null || cp -R dbaccess_extracao/* /tmp/out_dbaccess/)

# ==============================================================================
# ESTÁGIO 2: Runner (Imagem Gateway Híbrida Enxuta)
# ==============================================================================
FROM ubuntu:22.04 AS runner
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates gnupg2 gettext-base netcat-openbsd \
    unixodbc unixodbc-dev odbc-postgresql libc6 libtinfo5 libstdc++6 libaio1 \
    && rm -rf /var/lib/apt/lists/*

# Instalação limpa do Microsoft ODBC Driver 18 para SQL Server
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql18 && \
    rm -rf /var/lib/apt/lists/*

# Copia os artefatos estruturados direto do builder
COPY --from=builder /tmp/build/instantclient_21_3 /opt/oracle/instantclient_21_3
COPY --from=builder /tmp/out_dbaccess /opt/totvs/dbaccess/multi/

RUN echo /opt/oracle/instantclient_21_3 > /etc/ld.so.conf.d/oracle-instantclient.conf && ldconfig

WORKDIR /opt/totvs/dbaccess/multi
COPY ./dbaccess/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    (chmod +x dbaccess64 2>/dev/null || true) && \
    chmod -R 755 /opt/totvs/dbaccess/multi/

ENV ORACLE_HOME=/opt/oracle/instantclient_21_3
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient_21_3:$LD_LIBRARY_PATH

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]