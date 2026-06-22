FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Instala dependências, utilitários e os drivers de banco de dados
RUN apt-get update && apt-get install -y --no-install-recommends \
    gettext-base \
    netcat-openbsd \
    unixodbc \
    unixodbc-dev \
    odbc-postgresql \
    curl \
    ca-certificates \
    gnupg2 && \
    # Repositório Oficial Microsoft para Driver SQL Server
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 && \
    rm -rf /var/lib/apt/lists/*

# Alinhando com a estrutura de diretórios do binário corrigido
WORKDIR /opt/totvs/dbaccess/multi

# Copia os binários do dbaccess (devem estar na pasta bin local no build context)
COPY ./bin/ /opt/totvs/dbaccess/multi/

# Injeta os templates e o script de inicialização do ecossistema DevOps
COPY dbaccess.ini.tmpl /opt/totvs/dbaccess/multi/
COPY entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 7890

ENTRYPOINT ["entrypoint.sh"]