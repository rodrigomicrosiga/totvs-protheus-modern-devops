#!/bin/bash
set -e

echo "=== [dbAccess] Iniciando processo de configuração dinâmica ==="

# 1. Valida o tipo de banco e define o alvo de rede com base no .env
if [ "$DB_TYPE" = "POSTGRES" ]; then
    TARGET_HOST="protheus_postgres"
    TARGET_PORT="5432"
elif [ "$DB_TYPE" = "MSSQL" ]; then
    TARGET_HOST="protheus_sqlserver"
    TARGET_PORT="1433"
else
    echo "❌ Tipo de banco desconhecido no .env: $DB_TYPE"
    exit 1
fi

# 2. Loop de resiliência aguardando o banco responder na rede interna do Docker
echo "⏳ Aguardando conectividade com o banco em ${TARGET_HOST}:${TARGET_PORT}..."
while ! nc -z "$TARGET_HOST" "$TARGET_PORT"; do
    sleep 1
done
echo "✅ Conectividade com o banco de dados estabelecida!"

# Força a criação e entrada no diretório oficial da subpasta
mkdir -p /opt/totvs/dbaccess/multi/
cd /opt/totvs/dbaccess/multi/

echo "📝 Gerando dbaccess.ini oficial em: $(pwd)/dbaccess.ini"

# 3. Escrita do arquivo com base no template homologado
if [ "$DB_TYPE" = "POSTGRES" ]; then
    cat <<EOF > dbaccess.ini
[General]
LicenseServer=${LICENSE_SERVER_HOST}
LicensePort=${LICENSE_SERVER_PORT}
ODBC30=1
MaxStringSize=500
UseLargeRecno=1
ConsoleFile=/opt/totvs/dbaccess/log/dbaccess.log
ConsoleLog=1

[POSTGRES]
environments=${DB_NAME}
clientlibrary=/usr/lib/x86_64-linux-gnu/libodbc.so
CodePage=WIN1252

[POSTGRES/${DB_NAME}]
ConnectionMode=2
ConnectionString="DRIVER={PostgreSQL ANSI};SERVER=${DB_SERVER};PORT=${DB_PORT};DATABASE=${DB_NAME};Uid=${DB_USER};Pwd=${DB_PASS}"
UseRowInsDt=1
UseRowsStamp=1
EOF

elif [ "$DB_TYPE" = "MSSQL" ]; then
    cat <<EOF > dbaccess.ini
[General]
LicenseServer=${LICENSE_SERVER_HOST}
LicensePort=${LICENSE_SERVER_PORT}
MaxStringSize=500
UseLargeRecno=1
ConsoleFile=/opt/totvs/dbaccess/log/dbaccess.log
ConsoleLog=1

[MSSQL]
AutoTranslate=0
environments=${DB_NAME}
clientlibrary=/usr/lib/x86_64-linux-gnu/libodbc.so
compression=2

[MSSQL/${DB_NAME}]
ConnectionMode=2
ConnectionString="DRIVER={ODBC Driver 18 for SQL Server};SERVER=${DB_SERVER};PORT=${DB_PORT};DATABASE=${DB_NAME};Uid=${DB_USER};Pwd=${DB_PASS};TrustServerCertificate=yes"
IndexSpace=SECONDARY
UseRowInsDt=1
UseRowsStamp=1
EOF
fi

echo "✅ [dbAccess] dbaccess.ini gerado com sucesso!"
echo "🚀 Disparando o TOTVS dbAccess..."

# 4. Execução garantida por caminhos absolutos baseados na estrutura padrão
if [ -f "/opt/totvs/dbaccess/dbaccess64" ]; then
    exec /opt/totvs/dbaccess/dbaccess64
elif [ -f "/opt/totvs/dbaccess/multi/dbaccess64" ]; then
    exec /opt/totvs/dbaccess/multi/dbaccess64
else
    # Fallback caso esteja na pasta corrente
    exec ./dbaccess64
fi