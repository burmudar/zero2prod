#!/usr/bin/env bash
# quickly retrigger direnv
rootDir="$(cd $(dirname "${BASH_SOURCE[0]}")/.. && pwd)"

export __ZERO2PROD_ROOT_DIR="${rootDir}"
export __ZERO2PROD_LIB_PATH="${rootDir}/dev/lib.sh"
source ${__ZERO2PROD_LIB_PATH}

export __ZERO2PROD_ROOT_DIR="${rootDir}"

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

if [ ${CI:-0} == 1 ]; then
  rm -rf ~/.cargo/bin
fi

. ${rootDir}/dev/start-db.sh
