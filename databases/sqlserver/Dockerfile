FROM mcr.microsoft.com/mssql/server:2022-latest

USER root
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*

USER mssql
WORKDIR /usr/src/app
COPY init-protheus.sql /usr/src/app/

# Script interno para aguardar o SQL Server subir e executar a criação do banco
RUN echo '#!/bin/bash \n\
/opt/mssql/bin/sqlservr & \n\
echo "Aguardando SQL Server iniciar..." \n\
while ! nc -z localhost 1433; do sleep 1; done \n\
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -i init-protheus.sql -C \n\
wait' > /usr/src/app/entrypoint.sh && chmod +x /usr/src/app/entrypoint.sh

ENTRYPOINT ["/usr/src/app/entrypoint.sh"]