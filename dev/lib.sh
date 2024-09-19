#!/usr/bin/env bash

set -e

rootDir="$(dirname "${BASH_SOURCE[0]}")/.."

function root() {
  echo "${rootDir}"
}

function errorf() {
  echo >&2 "$1"
}

