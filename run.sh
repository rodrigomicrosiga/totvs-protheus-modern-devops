#!/bin/bash
# ==============================================================================
# TOTVS Protheus Modern DevOps - Environment Controller
# Author: Rodrigo dos Santos Brandão
# ==============================================================================
set -e

# Captura os argumentos
SGBD=$(echo "$1" | tr '[:upper:]' '[:lower:]')
SERVICE=$(echo "$2" | tr '[:upper:]' '[:lower:]')
COMMAND=$3

export SGBD  # <-- CRUCIAL: Torna a variável visível para o processo do Docker Compose

# Caso o segundo argumento seja "down", inverte as variáveis para manter compatibilidade clássica
if [ "$SERVICE" = "down" ]; then
    COMMAND="down"
    SERVICE=""
fi

# Valida se o comando base do banco foi passado de forma correta
if [ -z "$SGBD" ] || { [ "$SGBD" != "postgres" ] && [ "$SGBD" != "mssql" ] && [ "$SGBD" != "oracle" ] && [ "$SGBD" != "down" ]; }; then
    echo "❌ Uso correto: ./run.sh [postgres | mssql | oracle | down] [opcional: rest | telnet | soap | worker | upddistr] [opcional: command]"
    echo "👉 Exemplo Base:     ./run.sh postgres"
    echo "👉 Exemplo Worker:   ./run.sh postgres worker"
    echo "👉 Exemplo Migrador: ./run.sh postgres upddistr"
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

# Monta a cadeia de perfis ativos de forma dinâmica
PROFILES_ARGS="--profile $SGBD"
if [ -n "$SERVICE" ] && [ "$SERVICE" != "down" ]; then
    if [ "$SERVICE" != "rest" ] && [ "$SERVICE" != "telnet" ] && [ "$SERVICE" != "soap" ] && [ "$SERVICE" != "worker" ] && [ "$SERVICE" != "upddistr" ]; then
        echo "❌ Serviço especialista desconhecido: $SERVICE"
        echo "👉 Use: rest, telnet, soap, worker ou upddistr"
        exit 1
    fi
    PROFILES_ARGS="$PROFILES_ARGS --profile $SERVICE"
    echo "⚙️  Chaveando ecossistema dinamicamente para [${SGBD^^}] com serviço adicional [${SERVICE^^}]..."
else
    echo "⚙️  Chaveando ecossistema dinamicamente para [${SGBD^^}] (Apenas Infra Base + Core)..."
fi

# Determina e executa a ação final do Docker Compose de forma isolada
if [ "$COMMAND" = "down" ]; then
    if [ -n "$SERVICE" ]; then
        echo "🔻 Desligando especificamente o serviço especialista: [${SERVICE^^}]..."
        docker compose --env-file .env --env-file "$ENV_SPEC" stop appserver_$SERVICE
        docker compose --env-file .env --env-file "$ENV_SPEC" rm -f appserver_$SERVICE
    else
        echo "🔻 Desligando a stack base sob os perfis selecionados..."
        docker compose --env-file .env --env-file "$ENV_SPEC" $PROFILES_ARGS down -v
    fi
else
    # --------------------------------------------------------------------------
    # CENÁRIO ESPECIAL: DEPLOYER WORKER E COMPATIBILIZADOR UPDDISTR
    # --------------------------------------------------------------------------
    if [ "$SERVICE" = "worker" ] || [ "$SERVICE" = "upddistr" ]; then
        echo "🕵️  Mapeando estado atual dos contêineres Protheus ativos..."
        
        CORE_ACTIVE=$(docker compose --env-file .env --env-file "$ENV_SPEC" ps --status running --format json | grep -q "appserver_core" && echo "true" || echo "false")
        REST_ACTIVE=$(docker compose --env-file .env --env-file "$ENV_SPEC" ps --status running --format json | grep -q "appserver_rest" && echo "true" || echo "false")
        TELNET_ACTIVE=$(docker compose --env-file .env --env-file "$ENV_SPEC" ps --status running --format json | grep -q "appserver_telnet" && echo "true" || echo "false")

        echo "🛑 Isolando o RPO e Tabelas: Interrompendo temporariamente os serviços ativos para execução exclusiva..."
        [ "$CORE_ACTIVE" = "true" ] && docker compose --env-file .env --env-file "$ENV_SPEC" stop appserver_core
        [ "$REST_ACTIVE" = "true" ] && docker compose --env-file .env --env-file "$ENV_SPEC" stop appserver_rest
        [ "$TELNET_ACTIVE" = "true" ] && docker compose --env-file .env --env-file "$ENV_SPEC" stop appserver_telnet

        if [ "$SERVICE" = "worker" ]; then
            echo "🚀 Invocando o Protheus Automated Deploy Worker (Modo CLI Job com Force Build)..."
            set +e
            docker compose --env-file .env --env-file "$ENV_SPEC" run --build --rm appserver_worker
            EXEC_EXIT_CODE=$?
            set -e
        else
            echo "🚀 Inicializando Executor UPDDISTR Síncrono (Dicionário de Dados)..."
            
            # Remove arquivos antigos em qualquer variação de caixa para evitar falsos positivos
            rm -f ./protheus/systemload/Result.json ./protheus/systemload/result.json
            
            # Inicializa o container do UPDDISTR
            docker compose --env-file .env --env-file "$ENV_SPEC" up --build -d appserver_upddistr
            
            echo "⏳ Processando compatibilização do dicionário. Monitorando output do resultado (Aguarde)..."
            set +e
            while true; do
                # 🔍 Check agnóstico de caixa (Procura por result.json ou Result.json)
                TARGET_FILE=""
                if [ -f "./protheus/systemload/Result.json" ]; then
                    TARGET_FILE="./protheus/systemload/Result.json"
                elif [ -f "./protheus/systemload/result.json" ]; then
                    TARGET_FILE="./protheus/systemload/result.json"
                fi

                if [ -n "$TARGET_FILE" ]; then
                    echo "📝 Arquivo de resultado detectado: [$TARGET_FILE]"
                    cat "$TARGET_FILE"
                    echo ""
                    if grep -q "success" "$TARGET_FILE"; then
                        EXEC_EXIT_CODE=0
                    else
                        EXEC_EXIT_CODE=1
                    fi
                    break
                fi

                # Verifica se o container caiu antes de gerar o json
                CONTAINER_RUNNING=$(docker compose --env-file .env --env-file "$ENV_SPEC" ps --status running --format json | grep -q "protheus_upddistr" && echo "true" || echo "false")
                if [ "$CONTAINER_RUNNING" = "false" ] && [ -z "$TARGET_FILE" ]; then
                    echo "❌ ERRO CRÍTICO: O container protheus_upddistr encerrou inesperadamente sem gerar o arquivo de resultado!"
                    EXEC_EXIT_CODE=1
                    break
                fi
                sleep 5
            done
            set -e
            
            echo "🧹 Removendo container temporário do UPDDISTR..."
            docker compose --env-file .env --env-file "$ENV_SPEC" stop appserver_upddistr 2>/dev/null || true
            docker compose --env-file .env --env-file "$ENV_SPEC" rm -f appserver_upddistr 2>/dev/null || true
        fi

        if [ $EXEC_EXIT_CODE -eq 0 ]; then
            echo "✅ Processo [${SERVICE^^}] executado com sucesso total!"
        else
            echo "❌ Falha crítica detectada no processamento do [${SERVICE^^}]."
        fi

        echo "🔄 Restaurando o ecossistema original para o estado anterior..."
        [ "$CORE_ACTIVE" = "true" ] && docker compose --env-file .env --env-file "$ENV_SPEC" up -d appserver_core
        [ "$REST_ACTIVE" = "true" ] && docker compose --env-file .env --env-file "$ENV_SPEC" up -d appserver_rest
        [ "$TELNET_ACTIVE" = "true" ] && docker compose --env-file .env --env-file "$ENV_SPEC" up -d appserver_telnet

    # OUTROS SERVIÇOS ESPECIALISTAS TRADICIONAIS (REST, TELNET, SOAP)
    elif [ -n "$SERVICE" ] && [ "$SERVICE" != "down" ]; then
        echo "🚀 Acoplando o serviço especialista [${SERVICE^^}] de forma isolada..."
        docker compose --env-file .env --env-file "$ENV_SPEC" up --build --no-recreate -d appserver_$SERVICE
    else
        echo "🚀 Inicializando a infraestrutura base Protheus com banco [${SGBD^^}]..."
        docker compose --env-file .env --env-file "$ENV_SPEC" $PROFILES_ARGS up --build -d
    fi

    echo "📊 Status atual dos containers ativos da Malha:"
    docker compose --env-file .env --env-file "$ENV_SPEC" --profile "*" ps
fi