FROM postgres:16-alpine

# Instala dependências para geração de locales se necessário e configura o ambiente
ENV LANG=pt_BR.UTF-8
ENV LANGUAGE=pt_BR:pt
ENV LC_ALL=pt_BR.UTF-8

# Copia o script de inicialização do Protheus
COPY init-protheus.sh /docker-entrypoint-initdb.d/

# Otimizações de performance em disco e escrita para ambiente Protheus
RUN echo "shared_buffers = 512MB" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "work_mem = 32MB" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "maintenance_work_mem = 128MB" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "synchronous_commit = off" >> /usr/local/share/postgresql/postgresql.conf.sample