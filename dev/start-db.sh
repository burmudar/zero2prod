#!/usr/bin/env bash

set -e

source ${__ZERO2PROD_LIB_PATH:-"lib.sh"}

SKIP_INIT=${1:-"false"}
__DB_ENV=0


function db_env() {
  if [ ${__DB_ENV} == 0 ]; then
    echo "--- Exporting DB Env"
    export PGUSER="${PGUSER:=postgres}"
    export PGPASSWORD="${PGPASSWORD:=password}"

    export PGDATABASE="${POSTGRES_DB:=newsletter}"
    export PGPORT="${POSTGRES_PORT:=5432}"

    export PGHOST="$(root)/.db"
    export PGDATASOURCE="postgres:///${PGDATABASE}?host=${PGHOST}"
    export PGDATA="${PGHOST}/${PGDATABASE}"
    export PGLISTEN="${PGLISTEN:=localhost}"
  fi
  __DB_ENV=1
}

function setup_db() {
  db_env
  if [ ! -d ${PGHOST} ]; then
    mkdir -p ${PGHOST}
  fi

  if [ ! -d ${PGDATA} ]; then
    echo 'Initializing postgresql database...'
    initdb -U postgres "$PGDATA" --nosync --encoding=UTF8 --no-locale --auth=trust >/dev/null
    cat <<-EOF >>"$PGDATA"/postgresql.conf
        unix_socket_directories = '$PGHOST'
        listen_addresses = '$PGLISTEN'
        max_connections = 1000
        shared_buffers = 12MB
        fsync = off
        synchronous_commit = off
        full_page_writes = off
EOF
  fi

}

function migrate_db() {
  echo "--- Running DB migrations"
  export DATABASE_URL=${PGDATASOURCE}
  sqlx database create
  sqlx migrate run
}

function start_db() {
  echo "--- Starting DB"
  if ! pg_isready --quiet; then
    echo 'Starting postgresql database...'
    pg_ctl start -l "$PGHOST/log" 3>&-
  fi
}

db_env
if [ ${SKIP_INIT} == "false" ]; then
  setup_db
else
  echo "Skipping DB init"
fi
start_db
migrate_db

