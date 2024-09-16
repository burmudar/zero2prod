#!/usr/bin/env bash

set -e

function errorf() {
  echo >&2 "$1"
}

function dep_checks() {
  if ! [ -x "$(command -v psql)" ]; then
    errorf "Error: psql is not installed"
    exit 1
  fi

  if ! [ -x "$(command -v sqlx)" ]; then
    errorf "Error: sqlx is not installed"
    errorf "Use:"
    errorf "    cargo install --version 0.8.2 sqlx-cli --no-default-features --features postgres"
    errorf "to install it"
    exit 1
  fi
}

# quickly retrigger direnv
ROOT_DIR="$(cd $(dirname "${BASH_SOURCE[0]}")/.. && pwd)"

echo "Root: ${ROOT_DIR}"

function setup_db() {

  export PGUSER="${PGUSER:=postgres}"
  export PGPASSWORD="${PGPASSWORD:=password}"

  export PGDATABASE="${POSTGRES_DB:=newsletter}"
  export PGPORT="${POSTGRES_PORT:=5432}"

  export PGHOST="${ROOT_DIR}/.db"
  export PGDATASOURCE="postgres:///${PGDATABASE}?host=${PGHOST}"
  export PGDATA="${PGHOST}/${PGDATABASE}"

  if [ ! -d ${PGHOST} ]; then
    mkdir -p ${PGHOST}
  fi

  if [ ! -d ${PGDATA} ]; then
    echo 'Initializing postgresql database...'
    initdb -U postgres "$PGDATA" --nosync --encoding=UTF8 --no-locale --auth=trust >/dev/null
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

function migrate_db() {
  echo "--- Running DB migrations"
  export DATABASE_URL=${PGDATASOURCE}
  sqlx database create
  sqlx migrate run
}

dep_checks

if [ ${SKIP_INIT:-"false"} == "false" ]; then
  setup_db
else
  echo "Skipping DB init"
fi
migrate_db
