#!/bin/bash
set -e

ROLE=${1:-core}
echo "=== [AppServer] Inicializando Modo: [${ROLE^^}] ==="

# 1. Aguarda a retaguarda de infraestrutura estar online
echo "⏳ Validando conectividade com o barramento de infraestrutura..."
while ! nc -z protheus_dbaccess 7890; do sleep 1; done
while ! nc -z protheus_license 5555; do sleep 1; done
echo "✅ Conectividade com DbAccess e License Server estabelecida!"

# 2. Carga Inicial Isolada com Injeção Segura de Travas
echo "📦 Verificando integridade dos volumes isolados..."

# Garante a árvore mínima necessária dentro dos volumes do Docker
mkdir -p /totvs/protheus/system /totvs/protheus/systemload /totvs/protheus/log /totvs/protheus/data

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
        # Se os arquivos já vierem na raiz do zip (seu cenário atual), o script segue reto com segurança.
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
    echo "📂 [First Boot] Extraindo dados de carga em /totvs/protheus/systemload/ (Aguarde)..."
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
echo "📝 Gerando appserver.ini dinâmico..."

cat <<EOF > appserver.ini
[${ENV_NAME}]
SourcePath=/totvs/protheus/apo
RPOCustom=/totvs/protheus/apo/custom.rpo
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
DBPort=7890
DBAlias=${DB_NAME}
DBServer=protheus_dbaccess
DBDatabase=${DB_TYPE}

[Drivers]
Active=TCP
MultiProtocolPort=1
MultiProtocolPortSecure=0

[TCP]
TYPE=TCPIP
Port=1234

[LicenseClient]
Server=protheus_license
Port=5555

[General]
app_environment=${ENV_NAME}
ShowFullLog=0
MaxStringSize=500
MaxQuerySize=31960
PowerSchemeShowUpgradeSuggestion=0
ConsoleFile=/totvs/protheus/log/appserver.log
ConsoleLog=1
AsyncConsoleLog=1
BuildKillUsers=1

[WebApp]
Port=1234
LastMainProg=SIGAADV,SIGACFG,MPSDU,SIGAMDI
EnvServer=${ENV_NAME}
NonStopOnError=1

[WebMonitor]
Enable=1

[APP_MONITOR]
Enable=1

[TDS]
AllowMonitor=*
AllowApplyPatch=*
AllowEdit=*
EnableDisconnectUser=*
EnableSendMessage=*
EnableBlockNewConnection=*
EnableStopServer=*

[WebApp/webapp]
MPP=
EOF

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

echo "🚀 Disparando TOTVS Application Server Linux..."
exec ./appsrvlinux -console