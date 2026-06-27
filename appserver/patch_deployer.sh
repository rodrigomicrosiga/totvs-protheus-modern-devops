#!/bin/bash
set -e

echo "=== [Protheus-Worker] Iniciando Automação de Deploy de Patch ==="

CORE_HOST=${DBACCESS_SERVER:-protheus_core}
# Injeta dinamicamente a porta parametrizada no .env (com fallback para 1234 se estiver vazia)
CORE_PORT=${CORE_PORT_MULTI:-1234} 
PATCH_DIR="/totvs/protheus/patches_queue"
ENVIRONMENT=${ENV_NAME}

# 1. Aguarda o Core Master estar online e com o banco de dados pronto
echo "⏳ Aguardando liberação do semáforo do Core Master..."
while [ ! -f "/totvs/protheus/system/.protheus_db_ready" ]; do sleep 2; done
while ! nc -z "$CORE_HOST" "$CORE_PORT"; do sleep 1; done
echo "✅ Core Master pronto e responsivo na porta ${CORE_PORT} para atualizações!"

# 2. Varre a pasta em busca de novos Patches (.ptm) para aplicação
if [ -d "$PATCH_DIR" ] && [ "$(ls -A $PATCH_DIR/*.ptm 2>/dev/null)" ]; then
    echo "📦 Encontrado(s) patch(es) na fila de deploy. Iniciando processamento..."
    
    cd /totvs/protheus/bin/appserver
    
    for patch_file in "$PATCH_DIR"/*.ptm; do
        echo "⚙️ Aplicando patch: [$(basename "$patch_file")] no ambiente [$ENVIRONMENT]..."
        
        # Executa o utilitário CLI oficial de forma silenciosa e imperativa
        ./appsrvlinux -applypatch="$patch_file" -env="$ENVIRONMENT" -server="$CORE_HOST:$CORE_PORT" -silent || {
            echo "❌ ERRO CRÍTICO ao aplicar o patch: [$(basename "$patch_file")]"
            exit 1
        }
        
        echo "✅ Patch [$(basename "$patch_file")] aplicado com sucesso total!"
        # Move para uma pasta de backup/histórico interna para não reprocessar no próximo ciclo
        mkdir -p "$PATCH_DIR/applied"
        mv "$patch_file" "$PATCH_DIR/applied/"
    done
else
    echo "⏭️ Nenhuns patches pendentes (.ptm) encontrados na pasta de deploy. Pulando."
fi

echo "✅ [Protheus-Worker] Fluxo de deploy finalizado com sucesso!"