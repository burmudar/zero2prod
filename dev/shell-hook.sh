#!/usr/bin/env bash

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
}

if [ ${CI:-0} == 1 ]; then
  rm -rf ~/.cargo/bin
fi

. ${rootDir}/dev/start-db.sh
