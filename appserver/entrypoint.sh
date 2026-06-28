#!/bin/bash
set -e

# Traduz o argumento do container em minúsculas (core, rest, telnet, worker)
ROLE=$(echo "$1" | tr '[:upper:]' '[:lower:]')
echo "=== [AppServer] Inicializando Modo Especialista: [${ROLE^^}] ==="

# Mapeamento dinâmico das variáveis globais injetadas pelo Docker Compose
PORT=${APP_PORT_MULTI}
LICENSE_HOST=${LICENSE_SERVER:-protheus_license}
LICENSE_PORT=${LICENSE_SERVER_PORT:-5555}
DB_PORT_INI=${DBACCESS_PORT:-7890}
DB_SERVER_INI=${DBACCESS_SERVER:-protheus_dbaccess}

# Garante o fallback do nome do RPO Customizado caso não esteja mapeado
RPO_CUSTOM_TARGET="${RPO_CUSTOM_NAME:-custom}"

# Tratamento exclusivo para o nome do log do ConsoleFile baseado no serviço
case "$ROLE" in
    core)   LOG_NAME="appserver_core.log"   ;;
    rest)   LOG_NAME="appserver_rest.log"   ;;
    telnet) LOG_NAME="appserver_telnet.log" ;;
    worker) LOG_NAME="appserver_worker.log" ;;
    *)      LOG_NAME="appserver.log"        ;;
esac

# 1. Aguarda a retaguarda de infraestrutura estar online de forma flexível
echo "⏳ Validando conectividade com o barramento de infraestrutura..."
while ! nc -z "$DB_SERVER_INI" "$DB_PORT_INI"; do sleep 1; done
while ! nc -z "$LICENSE_HOST" "$LICENSE_PORT"; do sleep 1; done
echo "✅ Conectividade com DbAccess e License Server estabelecida!"

# 2. Carga Inicial Isolada com Injeção Segura de Travas
echo "📦 Verificando integridade dos volumes isolados..."

# Garante a árvore mínima necessária dentro dos volumes do Docker, incluindo a fila de patches e o rollback do RPO
mkdir -p /totvs/protheus/system /totvs/protheus/systemload /totvs/protheus/log /totvs/protheus/data /totvs/protheus/apo/aporollback /totvs/protheus/patches_queue

# --- EXTRAÇÃO ISOLADA DO FISCAL.ZIP ---
if [ ! -f "/totvs/protheus/system/.fiscal_boot_done" ]; then
    if [ -f "/tmp/source_system/fiscal.zip" ]; then
        echo "📂 [First Boot] Extraindo dicionários de sistema (fiscal.zip)..."
        touch /totvs/protheus/system/.fiscal_boot_done
        unzip -nq /tmp/source_system/fiscal.zip -d /totvs/protheus/system/
        echo "✅ Arquivos do fiscal.zip populados com sucesso!"
    fi
else
    echo "⏭️  Arquivos do fiscal.zip já inicializados anteriormente. Pulando."
fi

# --- EXTRAÇÃO ISOLADA DO MENUS.ZIP ---
if [ ! -f "/totvs/protheus/system/.menus_boot_done" ]; then
    if [ -f "/tmp/source_system/menus.zip" ]; then
        echo "📂 [First Boot] Extraindo menus corporativos (menus.zip)..."
        touch /totvs/protheus/system/.menus_boot_done
        unzip -nq /tmp/source_system/menus.zip -d /totvs/protheus/system/
        
        # Tratamento dinâmico: Se os menus por acaso caírem em uma subpasta, move para a raiz.
        if [ -d "/totvs/protheus/system/menus" ]; then
            echo "📂 Ajustando estrutura de diretórios do menus.zip para a raiz da system..."
            mv /totvs/protheus/system/menus/* /totvs/protheus/system/ 2>/dev/null || true
            rmdir /totvs/protheus/system/menus 2>/dev/null || true
        fi
        echo "✅ Arquivos do menus.zip populados com sucesso!"
    fi
else
    echo "⏭️  Arquivos do menus.zip já inicializados anteriormente. Pulando."
fi

# --- EXTRAÇÃO ISOLADA DO SYSTEMLOAD (DICIONARIOS, HELP, WEB) ---
if [ ! -f "/totvs/protheus/systemload/.systemload_boot_done" ]; then
    echo "📂 [First Boot] Extraindo dados de carga in /totvs/protheus/systemload/ (Aguarde)..."
    touch /totvs/protheus/systemload/.systemload_boot_done
    
    [ -f "/tmp/source_systemload/dicionarios.zip" ] && unzip -nq /tmp/source_systemload/dicionarios.zip -d /totvs/protheus/systemload/
    [ -f "/tmp/source_systemload/help.zip" ] && unzip -nq /tmp/source_systemload/help.zip -d /totvs/protheus/systemload/
    [ -f "/tmp/source_systemload/web.zip" ] && unzip -nq /tmp/source_systemload/web.zip -d /totvs/protheus/systemload/
    echo "✅ Volume systemload populado com sucesso!"
else
    echo "⏭️  Volume systemload já inicializado anteriormente. Pulando extração."
fi

# 3. Renderização dinâmica do appserver.ini com as variáveis validadas
cd /totvs/protheus/bin/appserver
echo "📝 Gerando appserver.ini dinâmico para o modo [${ROLE^^}]..."

# Escrita limpa sem escape de variáveis locais, mapeando dinamicamente o nome do RPO Customizado
cat <<EOF > appserver.ini
[${ENV_NAME}]
SourcePath=/totvs/protheus/apo
RPOCustom=/totvs/protheus/apo/${RPO_CUSTOM_TARGET}.rpo
RPOTLPP=/totvs/protheus/apo/tlpp.rpo
RootPath=/totvs/protheus
StartPath=/system/
RpoDb=SQL
RpoLanguage=Multi
RpoVersion=120
LocalFiles=SQLITE
LocalDbExtension=.db
StartSysInDB=1
TopMemoMega=50
DBPort=${DB_PORT_INI}
DBAlias=${DB_NAME}
DBServer=${DB_SERVER_INI}
DBDatabase=${DB_TYPE}

[Drivers]
Active=TCP
MultiProtocolPort=1
MultiProtocolPortSecure=0

[TCP]
TYPE=TCPIP
Port=${PORT}

[LicenseClient]
Server=${LICENSE_HOST}
Port=${LICENSE_PORT}

[General]
app_environment=${ENV_NAME}
ShowFullLog=0
MaxStringSize=500
MaxQuerySize=31960
PowerSchemeShowUpgradeSuggestion=0
ConsoleFile=/totvs/protheus/log/${LOG_NAME}
ConsoleLog=1
AsyncConsoleLog=1
BuildKillUsers=1

[WebApp]
Port=${PORT}
LastMainProg=SIGAADV,SIGACFG,MPSDU,SIGAMDI
EnvServer=${ENV_NAME}
NonStopOnError=1
EOF

# 🛡️ Injeção de Segurança e Governança Cirúrgica Baseada no Papel (Bloqueio Total vs. Permissão no Worker)
if [ "$ROLE" = "worker" ]; then
    cat <<EOF >> appserver.ini

[WebMonitor]
Enable=1

[APP_MONITOR]
Enable=1
Gui=1

[TDS]
AllowMonitor=*
AllowApplyPatch=*
AllowEdit=*
EnableDisconnectUser=*
EnableSendMessage=*
EnableBlockNewConnection=*
EnableStopServer=*
EOF
else
    # Bloqueio rigoroso de governança de patches/compilação nos ambientes Core, Rest e Telnet
    cat <<EOF >> appserver.ini

[WebMonitor]
Enable=0

[APP_MONITOR]
Enable=0
Gui=0

[TDS]
AllowMonitor=*
AllowApplyPatch=0
AllowEdit=0
EnableDisconnectUser=0
EnableSendMessage=0
EnableBlockNewConnection=0
EnableStopServer=0
EOF
fi

# Bloco estrutural WebApp comum a todos
cat <<EOF >> appserver.ini

[WebApp/webapp]
MPP=
EOF

# Append dos blocos especialistas dedicados (REST / TELNET)
if [ "$ROLE" = "rest" ]; then
    cat <<EOF >> appserver.ini

[HTTPJOB]
Main=HTTP_START
Environment=${ENV_NAME}

[ONSTART]
Jobs=HTTPJOB
RefreshRate=120

[HTTPV11]
Enable=1
Sockets=HTTPREST

[HTTPREST]
Port=${REST_HTTP_PORT}
URIs=HTTPURI
SECURITY=1

[HTTPURI]
URL=${REST_URI}
PrepareIn=${REST_PREP_ENV}
Instances=${REST_INSTANCES}
Stateless=1
CORSEnable=1
AllowOrigin=*
EOF
elif [ "$ROLE" = "telnet" ]; then
    cat <<EOF >> appserver.ini

[TELNET]
Enable=1
Environment=${ENV_NAME}
Main=SIGAACD
Port=${TELNET_PORT}
EOF
fi

# 4. Inicialização do Binário Oficial com Verificação de Sanidade
echo "🔍 Validando integridade física do executável TOTVS..."
if [ ! -f "appsrvlinux" ]; then
    echo "❌ ERRO CRÍTICO: O binário appsrvlinux NÃO foi encontrado no diretório atual ($(pwd))!"
    echo "📂 Conteúdo atual da pasta bin/appserver:"
    ls -la
    exit 1
fi

echo "🔑 Forçando permissões de execução no binário..."
chmod +x appsrvlinux

# Se for o core master, assinala o semáforo para liberar os nós especialistas
if [ "$ROLE" = "core" ]; then
    echo "🎯 Criando semáforo de prontidão (.protheus_db_ready)..."
    touch /totvs/protheus/system/.protheus_db_ready
fi

# ⚡ ORCHESTRATION ENGINE: Chaveamento de Processo Foreground vs Background baseado na ROLE
if [ "$ROLE" = "worker" ]; then
    echo "🚀 Preparando ambiente local do Worker..."
    cd /totvs/protheus/bin/appserver
    
    if [ -f "/usr/local/bin/patch_deployer.sh" ]; then
        echo "🤖 [Worker] Assumindo controle do contêiner em Foreground para execução síncrona..."
        exec /usr/local/bin/patch_deployer.sh
    else
        echo "❌ ERRO CRÍTICO: O script /usr/local/bin/patch_deployer.sh não foi encontrado!"
        exit 1
    fi
else
    # Comportamento padrão inalterado para CORE, REST e TELNET
    echo "🚀 Disparando TOTVS Application Server Linux no modo [${ROLE^^}]..."
    cd /totvs/protheus/bin/appserver
    exec ./appsrvlinux -console
fi