#!/usr/bin/env bash

set +x

ROOT_DIR="$(cd $(dirname "${BASH_SOURCE[0]}")/.. && pwd)"

echo "Root: ${ROOT_DIR}"

function setup_db() {

  export PGUSER="${PGUSER:=postgres}"
  export PGPASSWORD="${PGPASSWORD:=password}"

  export PGDATABASE="${POSTGRES_DB:=newsletter}"
  export PGPORT="${POSTGRES_PORT:=5432}"

  export PGHOST="${ROOT_DIR}/.db"
  export PGDATASOURCE="posgres:///postgres?host=${PGHOST}"
  export PGDATA="${PGHOST}/postgres"

  if [ ! -d ${PGHOST} ]; then
    mkdir -p ${PGHOST}
  fi

  if [ ! -d ${PGDATA} ]; then
    echo 'Initializing postgresql database...'
    initdb "$PGDATA" --nosync --encoding=UTF8 --no-locale --auth=trust >/dev/null
    cat <<-EOF >>"$PGDATA"/postgresql.conf
        unix_socket_directories = '$PGHOST'
        listen_addresses = 'localhost'
        max_connections = 1000
        shared_buffers = 12MB
        fsync = off
        synchronous_commit = off
        full_page_writes = off
EOF
  fi

  if ! pg_isready --quiet; then
    echo 'Starting postgresql database...'
    pg_ctl start -l "$PGHOST/log" 3>&-
  fi
}

setup_db
