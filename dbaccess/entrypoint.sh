#!/bin/bash
set -e

echo "=== [dbAccess] Iniciando processo de configuração dinâmica ==="

# 1. Valida o tipo de banco e define o alvo de rede com base no .env
if [ "$DB_TYPE" = "POSTGRES" ]; then
    TARGET_HOST="protheus_postgres"
    TARGET_PORT="5432"
    CFG_TYPE="POSTGRES"
elif [ "$DB_TYPE" = "MSSQL" ]; then
    TARGET_HOST="protheus_sqlserver"
    TARGET_PORT="1433"
    CFG_TYPE="MSSQL"
elif [ "$DB_TYPE" = "ORACLE" ]; then
    TARGET_HOST="protheus_oracle"
    TARGET_PORT="1521"
    CFG_TYPE="ORACLE"
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

# Força a criação do diretório de log exigido pelo console do DbAccess
mkdir -p /opt/totvs/dbaccess/log/

# Força a criação e entrada no diretório oficial da subpasta multi
mkdir -p /opt/totvs/dbaccess/multi/
cd /opt/totvs/dbaccess/multi/

# Define o caminho correto do utilitário dbaccesscfg
if [ -f "/opt/totvs/dbaccess/multi/dbaccesscfg" ]; then
    CFG_BIN="/opt/totvs/dbaccess/multi/dbaccesscfg"
else
    CFG_BIN="./dbaccesscfg"
fi

echo "📝 Limpando resíduos e gerando parâmetros de infraestrutura via dbaccesscfg..."

# Remove arquivo anterior se existir para garantir build limpa pelo utilitário
rm -f dbaccess.ini

# Parâmetros puramente globais para a seção [GENERAL]
GEN_OPTS="LicenseServer=${LICENSE_SERVER_HOST};LicensePort=${LICENSE_SERVER_PORT};MaxStringSize=500;UseLargeRecno=1;ConsoleFile=/opt/totvs/dbaccess/log/dbaccess.log;ConsoleLog=1;MemoAsBlob=0"

# 3. Execução do dbaccesscfg com os escopos corrigidos
if [ "$DB_TYPE" = "ORACLE" ]; then
    CONN_STR="//${DB_SERVER}:${DB_PORT}/${DB_SERVICE_NAME}"
    
    # Exporta a variável de ambiente para o SO do contêiner, garantindo a localização da OCI
    export ORACLE_HOME=/opt/oracle/instantclient_21_3
    export LD_LIBRARY_PATH=$ORACLE_HOME:$LD_LIBRARY_PATH

    BANK_OPTS="ConnectionString=${CONN_STR};ConnectionMode=2;LogAction=0;MemoAsBlob=1;Disable=0;TableSpace=;IndexSpace="
    
    $CFG_BIN -u "${DB_USER}" -p "${DB_PASS}" -d "${CFG_TYPE}" -a "${DB_NAME}" -o "${BANK_OPTS}" -g "${GEN_OPTS}" -c "/opt/oracle/instantclient_21_3/libclntsh.so"

    # Localiza a linha do ClientLibrary e injeta o ORACLE_HOME logo abaixo dela, sem quebras sobressalentes
    sed -i '/ClientLibrary=\/opt\/oracle\/instantclient_21_3\/libclntsh.so/a ORACLE_HOME=/opt/oracle/instantclient_21_3' dbaccess.ini

elif [ "$DB_TYPE" = "POSTGRES" ]; then
    CONN_STR="DRIVER={PostgreSQL ANSI};SERVER=${DB_SERVER};PORT=${DB_PORT};DATABASE=${DB_NAME};Uid=${DB_USER};Pwd=${DB_PASS}"
    BANK_OPTS="ConnectionString=${CONN_STR};ConnectionMode=2;UseRowInsDt=1;UseRowsStamp=1"
    
    $CFG_BIN -u "${DB_USER}" -p "${DB_PASS}" -d "${CFG_TYPE}" -a "${DB_NAME}" -o "${BANK_OPTS}" -g "${GEN_OPTS}" -c "/usr/lib/x86_64-linux-gnu/libodbc.so"
    
    sed -i '/ClientLibrary=\/usr\/lib\/x86_64-linux-gnu\/libodbc.so/a CodePage=WIN1252' dbaccess.ini

elif [ "$DB_TYPE" = "MSSQL" ]; then
    CONN_STR="DRIVER={ODBC Driver 18 for SQL Server};SERVER=${DB_SERVER};PORT=${DB_PORT};DATABASE=${DB_NAME};Uid=${DB_USER};Pwd=${DB_PASS};TrustServerCertificate=yes"
    BANK_OPTS="ConnectionString=${CONN_STR};ConnectionMode=2;IndexSpace=SECONDARY;UseRowInsDt=1;UseRowsStamp=1"
    
    $CFG_BIN -u "${DB_USER}" -p "${DB_PASS}" -d "${CFG_TYPE}" -a "${DB_NAME}" -o "${BANK_OPTS}" -g "${GEN_OPTS}" -c "/usr/lib/x86_64-linux-gnu/libodbc.so"
    
    sed -i '/ClientLibrary=\/usr\/lib\/x86_64-linux-gnu\/libodbc.so/a AutoTranslate=0\ncompression=2' dbaccess.ini
fi

# Remove eventuais linhas em branco duplas geradas no fim do arquivo pelo dbaccesscfg
sed -i '/^$/N;/^\n$/D' dbaccess.ini

echo "✅ [dbAccess] dbaccess.ini gerado e estruturado com sucesso no padrão ideal!"
echo "🚀 Disparando o TOTVS dbAccess..."

# 4. Execução garantida por caminhos absolutos baseados na estrutura padrão
if [ -f "/opt/totvs/dbaccess/dbaccess64" ]; then
    exec /opt/totvs/dbaccess/dbaccess64
else
    exec ./dbaccess64
fi