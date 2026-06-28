#!/bin/bash
set -e

PATCH_DIR="/totvs/protheus/patches_queue"
APO_DIR="/totvs/protheus/apo"
ROLLBACK_DIR="/totvs/protheus/apo/aporollback"
ENVIRONMENT="${ENV_NAME}"

echo "=== [Protheus-Worker] Inicializando Processamento de Patches em Modo CLI ==="

# --- ETAPA A: NORMALIZAÇÃO DE EXTENSÕES ---
if [ -d "$PATCH_DIR" ]; then
    find "$PATCH_DIR" -maxdepth 1 -type f -iname "*.ptm" | while read -r file; do
        ext="${file##*.}"
        if [ "$ext" != "ptm" ]; then
            echo "📝 [Normalizador] Ajustando extensão do arquivo: [$(basename "$file")] para minúsculo..."
            mv "$file" "${file%.*}.ptm"
        fi
    done
fi

# --- ETAPA B: APLICAÇÃO EM LOTE ---
if [ -d "$PATCH_DIR" ] && find "$PATCH_DIR" -maxdepth 1 -type f -name "*.ptm" | grep -q .; then
    echo "📦 Encontrado(s) pacote(s) na fila de deploy. Iniciando processamento..."
    
    cd /totvs/protheus/bin/appserver
    
    find "$PATCH_DIR" -maxdepth 1 -type f -name "*.ptm" | sort | while read -r patch_file; do
        PATCH_NAME=$(basename "$patch_file")
        TARGET_RPO="tttm120.rpo"

        # 🛡️ BACKUP PREVENTIVO DO RPO
        if [ -f "${APO_DIR}/${TARGET_RPO}" ]; then
            echo "💾 Fazendo backup de [${TARGET_RPO}] para o diretório de rollback..."
            cp -p "${APO_DIR}/${TARGET_RPO}" "${ROLLBACK_DIR}/${TARGET_RPO}"
            BACKUP_EXISTS="true"
        else
            echo "⚠️  Aviso: [${TARGET_RPO}] não foi encontrado para backup inicial."
            BACKUP_EXISTS="false"
        fi

        echo "⚙️ Aplicando [${PATCH_NAME}] no ambiente [${ENVIRONMENT}]..."
        TMP_LOG="/tmp/patch_exec.log"
        
        # EXECUÇÃO CLI OFICIAL NATIVA DO TDN
        ./appsrvlinux -compile -applypatch -files="$patch_file" -env="$ENVIRONMENT" > "$TMP_LOG" 2>&1
        cat "$TMP_LOG"

        # ⚡ VALIDAÇÃO PRECISA: Valida o sucesso real baseado no report oficial da TOTVS
        if grep -q "Patch successfully applied" "$TMP_LOG"; then
            EXEC_SUCCESS="true"
        else
            EXEC_SUCCESS="false"
        fi

        if [ "$EXEC_SUCCESS" = "true" ]; then
            echo "✅ Patch [${PATCH_NAME}] aplicado com sucesso total!"
            mkdir -p "$PATCH_DIR/applied"
            mv "$patch_file" "$PATCH_DIR/applied/"
            
            if [ "$BACKUP_EXISTS" = "true" ]; then
                rm -f "${ROLLBACK_DIR}/${TARGET_RPO}"
            fi
        else
            echo "❌ ERRO CRÍTICO detectado durante a aplicação de [${PATCH_NAME}]!"
            if [ "$BACKUP_EXISTS" = "true" ]; then
                echo "🔄 [ROLLBACK] Restaurando arquivo original [${TARGET_RPO}]..."
                cp -p "${ROLLBACK_DIR}/${TARGET_RPO}" "${APO_DIR}/${TARGET_RPO}"
                rm -f "${ROLLBACK_DIR}/${TARGET_RPO}"
                echo "💥 Restauração executada com sucesso."
            fi
            mkdir -p "$PATCH_DIR/error"
            mv "$patch_file" "$PATCH_DIR/error/"
            exit 1
        fi
        rm -f "$TMP_LOG"
    done
else
    echo "⏭️  Nenhum patch encontrado na fila de deploy (*.ptm). Finalizando Job."
fi

echo "=== [Protheus-Worker] Trabalho finalizado com sucesso! ==="
exit 0