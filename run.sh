#!/bin/bash
# ==============================================================================
# TOTVS Protheus Modern DevOps - Environment Controller
# Author: Rodrigo dos Santos Brandão
# ==============================================================================
set -e

SGBD=$(echo "$1" | tr '[:upper:]' '[:lower:]')
COMMAND=$2

# Valida se o comando base foi passado de forma correta
if [ -z "$SGBD" ] || { [ "$SGBD" != "postgres" ] && [ "$SGBD" != "mssql" ] && [ "$SGBD" != "oracle" ] && [ "$SGBD" != "down" ]; }; then
    echo "❌ Uso correto: ./run.sh [postgres | mssql | oracle | down] [opcional: command]"
    echo "👉 Exemplo: ./run.sh postgres"
    echo "👉 Exemplo: ./run.sh oracle"
    echo "👉 Exemplo: ./run.sh mssql down"
    exit 1
fi

# Cenário de destruição total do ambiente (down)
if [ "$SGBD" = "down" ]; then
    echo "🛑 Derrubando todos os perfis e limpando volumes persistentes..."
    docker compose --profile postgres --profile sqlserver --profile oracle down -v
    echo "✅ Ambiente totalmente limpo!"
    exit 0
fi

# Configuração dinâmica dos seletores de ambiente do .env
if [ "$SGBD" = "postgres" ]; then
    echo "⚙️  Configurando .env dinamicamente para POSTGRESQL 16..."
    sed -i 's/^DB_TYPE=.*/DB_TYPE=POSTGRES/' .env
    sed -i 's/^DB_SERVER=.*/DB_SERVER=protheus_postgres/' .env
    sed -i 's/^DB_PORT=.*/DB_PORT=5432/' .env
    PROFILE="postgres"

elif [ "$SGBD" = "mssql" ]; then
    echo "⚙️  Configurando .env dinamicamente para MS SQL SERVER 2022..."
    sed -i 's/^DB_TYPE=.*/DB_TYPE=MSSQL/' .env
    sed -i 's/^DB_SERVER=.*/DB_SERVER=protheus_sqlserver/' .env
    sed -i 's/^DB_PORT=.*/DB_PORT=1433/' .env
    PROFILE="sqlserver"

elif [ "$SGBD" = "oracle" ]; then
    echo "⚙️  Configurando .env dinamicamente para ORACLE DATABASE 21c..."
    sed -i 's/^DB_TYPE=.*/DB_TYPE=ORACLE/' .env
    sed -i 's/^DB_SERVER=.*/DB_SERVER=protheus_oracle/' .env
    sed -i 's/^DB_PORT=.*/DB_PORT=1521/' .env
    PROFILE="oracle"
fi

# Determina a ação do Docker Compose (default: up)
if [ "$COMMAND" = "down" ]; then
    echo "🔻 Desligando o perfil $PROFILE..."
    docker compose --profile "$PROFILE" down -v
else
    echo "🚀 Inicializando o ecossistema Protheus sob o perfil: [$PROFILE]..."
    docker compose --profile "$PROFILE" up --build -d
    echo "📊 Status dos containers ativos:"
    docker compose --profile "$PROFILE" ps
fi