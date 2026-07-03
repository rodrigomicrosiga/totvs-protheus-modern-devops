#!/bin/bash
set -e

# Alinhado dinamicamente com o volume do docker-compose
STAGING_DIR="/totvs/protheus/patches_queue"
APO_DIR="/totvs/protheus/apo"
ROLLBACK_DIR="/totvs/protheus/apo/aporollback"
ENVIRONMENT="${ENV_NAME}"
CUSTOM_RPO="${RPO_CUSTOM_NAME:-custom}.rpo"
LIST_FILE="/tmp/fontes_compilacao.txt"
TMP_LOG="/tmp/compile_exec.log"

echo "=== [Protheus-Compiler] Inicializando Esteira de Compilação GitOps ==="

# 1. Valida se existem fontes injetados pelo robô no diretório de staging
if [ -d "$STAGING_DIR" ]; then
    echo "🔍 Varrendo diretório de staging de customizados..."
    find "$STAGING_DIR" -type f \( -name "*.prw" -o -name "*.tlpp" \) > "$LIST_FILE"
    
    TOTAL_FILES=$(wc -l < "$LIST_FILE")
    if [ "$TOTAL_FILES" -eq 0 ]; then
        echo "❌ ERRO CRÍTICO: Nenhum arquivo .prw ou .tlpp localizado no staging para compilação!"
        rm -f "$LIST_FILE"
        exit 1
    fi
    echo "🎯 Foram identificados [${TOTAL_FILES}] fontes modificados no PR para compilação."
else
    echo "❌ ERRO CRÍTICO: O diretório de staging ${STAGING_DIR} não foi localizado!"
    exit 1
fi

# 2. Backup preventivo do RPO customizado atual
if [ -f "${APO_DIR}/${CUSTOM_RPO}" ]; then
    echo "💾 [Segurança] Gerando backup preventivo do repositório customizado [${CUSTOM_RPO}]..."
    mkdir -p "$ROLLBACK_DIR"
    cp -p "${APO_DIR}/${CUSTOM_RPO}" "${ROLLBACK_DIR}/${CUSTOM_RPO}"
    BACKUP_EXISTS="true"
else
    echo "⚠️  Aviso: Repositório [${CUSTOM_RPO}] não existe. Um novo RPO Customizado será gerado do zero."
    BACKUP_EXISTS="false"
fi

# 3. Executa a compilação via CLI oficial da TOTVS
cd /totvs/protheus/bin/appserver
echo "⚙️  Invocando compilador nativo da TOTVS para o ambiente [${ENVIRONMENT}]..."

set +e
./appsrvlinux -compile -list="$LIST_FILE" -env="$ENVIRONMENT" > "$TMP_LOG" 2>&1
EXEC_EXIT_CODE=$?
set -e

# Descarrega o log completo no terminal para o GitHub Actions capturar
cat "$TMP_LOG"

# 4. Validação rigorosa por assinatura textual de erro do ADVPL/TLPP
if grep -qi "error" "$TMP_LOG" || grep -qi "syntax error" "$TMP_LOG" || [ $EXEC_EXIT_CODE -ne 0 ]; then
    echo "❌ FALHA CRÍTICA: Detectado erro de sintaxe ou compilação no código enviado!"
    
    if [ "$BACKUP_EXISTS" = "true" ]; then
        echo "🔄 [ROLLBACK] Restaurando versão estável anterior do RPO [${CUSTOM_RPO}]..."
        cp -p "${ROLLBACK_DIR}/${CUSTOM_RPO}" "${APO_DIR}/${CUSTOM_RPO}"
        rm -f "${ROLLBACK_DIR}/${CUSTOM_RPO}"
        echo "✅ Repositório customizado restaurado com sucesso."
    fi
    
    rm -f "$LIST_FILE" "$TMP_LOG"
    exit 1 # Sinaliza falha real para derrubar a esteira
else
    echo "✅ SUCESSO TOTAL: Todos os fontes customizados foram integrados com sucesso ao RPO!"
    if [ "$BACKUP_EXISTS" = "true" ]; then
        echo "🧹 [Limpeza] Removendo backup de contingência temporário..."
        rm -f "${ROLLBACK_DIR}/${CUSTOM_RPO}"
    fi
fi

rm -f "$LIST_FILE" "$TMP_LOG"
echo "=== [Protheus-Compiler] Compilação finalizada com sucesso! ==="
exit 0