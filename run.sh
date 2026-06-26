#!/bin/bash
# ==============================================================================
# TOTVS Protheus Modern DevOps - Environment Controller
# Author: Rodrigo dos Santos Brandão
# ==============================================================================
set -e

# Captura e converte para caixa baixa (ex: POSTGRES -> postgres)
SGBD=$(echo "$1" | tr '[:upper:]' '[:lower:]')
export SGBD  # <-- CRUCIAL: Torna a variável visível para o processo do Docker Compose

SGBD=$(echo "$1" | tr '[:upper:]' '[:lower:]')
SERVICE=$(echo "$2" | tr '[:upper:]' '[:lower:]')
COMMAND=$3

export SGBD # <-- Adicione esta linha para expor a variável ao escopo do Docker Compose

# Caso o segundo argumento seja "down", inverte as variáveis para manter compatibilidade clássica (ex: ./run.sh postgres down)
if [ "$SERVICE" = "down" ]; then
    COMMAND="down"
    SERVICE=""
fi

# Valida se o comando base do banco foi passado de forma correta
if [ -z "$SGBD" ] || { [ "$SGBD" != "postgres" ] && [ "$SGBD" != "mssql" ] && [ "$SGBD" != "oracle" ] && [ "$SGBD" != "down" ]; }; then
    echo "❌ Uso correto: ./run.sh [postgres | mssql | oracle | down] [opcional: rest | telnet | soap] [opcional: command]"
    echo "👉 Exemplo Base:     ./run.sh postgres"
    echo "👉 Exemplo Rest API: ./run.sh postgres rest"
    echo "👉 Exemplo Derrubar: ./run.sh postgres down"
    exit 1
fi

# ------------------------------------------------------------------------------
# INTERCEPTOR CRÍTICO: Cenário de destruição total do ambiente (down global)
# ------------------------------------------------------------------------------
if [ "$SGBD" = "down" ]; then
    echo "🛑 Derrubando a infraestrutura global e limpando volumes persistentes..."
    
    ENV_ARG=""
    if [ -f ".env" ]; then
        ENV_ARG="--env-file .env"
    fi

    # Redireciona o fluxo de stderr (2) para o null, matando os WARNs de parsing visual do terminal
    docker compose $ENV_ARG --profile "*" down -v 2>/dev/null
    
    echo "✅ Ambiente totalmente limpo com segurança!"
    exit 0
fi

# Chaveamento de variáveis baseado no banco escolhido
ENV_SPEC=".env.$SGBD"
if [ ! -f "$ENV_SPEC" ]; then
    echo "❌ Erro crítico: O arquivo de ambiente especialista $ENV_SPEC não foi localizado na raiz!"
    exit 1
fi

# Monta a cadeia de perfis ativos de forma dinâmica (SGBD sempre ativo + Serviço opcional se existir)
PROFILES_ARGS="--profile $SGBD"
if [ -n "$SERVICE" ] && [ "$SERVICE" != "down" ]; then
    # Valida se o serviço especialista solicitado é conhecido na topologia
    if [ "$SERVICE" != "rest" ] && [ "$SERVICE" != "telnet" ] && [ "$SERVICE" != "soap" ]; then
        echo "❌ Serviço especialista desconhecido: $SERVICE"
        echo "👉 Use: rest, telnet ou soap"
        exit 1
    fi
    PROFILES_ARGS="$PROFILES_ARGS --profile $SERVICE"
    echo "⚙️  Chaveando ecossistema dinamicamente para [${SGBD^^}] com serviço adicional [${SERVICE^^}]..."
else
    echo "⚙️  Chaveando ecossistema dinamicamente para [${SGBD^^}] (Apenas Infra Base + Core)..."
fi

# Determina e executa a ação final do Docker Compose
if [ "$COMMAND" = "down" ]; then
    echo "🔻 Desligando a stack sob os perfis selecionados..."
    docker compose --env-file .env --env-file "$ENV_SPEC" $PROFILES_ARGS down -v
else
    echo "🚀 Inicializando o ecossistema Protheus IaC..."
    docker compose --env-file .env --env-file "$ENV_SPEC" $PROFILES_ARGS up --build -d
    echo "📊 Status dos containers ativos:"
    docker compose --env-file .env --env-file "$ENV_SPEC" $PROFILES_ARGS ps
fi