#!/bin/sh
set -e

echo "=== [dbAccess] Iniciando processo de configuração dinâmica ==="

# 1. Valida se as variáveis essenciais foram passadas
if [ -z "$DB_TYPE" ] || [ -z "$DB_SERVER" ] || [ -z "$DB_PORT" ]; then
    echo "❌ Erro: Variáveis de ambiente estruturais (DB_TYPE, DB_SERVER, DB_PORT) não foram definidas."
    exit 1
fi

# 2. Aguarda o Banco de Dados ficar online
echo "⏳ Aguardando conectividade com o banco em ${DB_SERVER}:${DB_PORT}..."
while ! nc -z "$DB_SERVER" "$DB_PORT"; do
  sleep 2
done
echo "✅ Banco de dados detectado e online!"

# 3. Cria o diretório de log caso não exista para evitar falhas no boot
mkdir -p /opt/totvs/dbaccess/log

# 4. Renderiza o arquivo .ini a partir do template com as variáveis de ambiente
envsubst < /opt/totvs/dbaccess/multi/dbaccess.ini.tmpl > /opt/totvs/dbaccess/multi/dbaccess.ini

echo "📝 Arquivo dbaccess.ini gerado com sucesso!"
echo "🚀 Inicializando o TOTVS dbAccess..."

# 5. Executa o binário do DbAccess substituindo o processo do container (PID 1)
exec /opt/totvs/dbaccess/multi/dbaccess64