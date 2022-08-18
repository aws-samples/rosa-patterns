#!/bin/bash

set -eu

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ROOT_PATH="$SCRIPT_PATH/.."

pushd $ROOT_PATH
    echo -e "\n[LINTING]"
    cfn-lint --info $PWD/*.yml

    echo -e "\n[SECURITY-SCAN]"
    docker run -v $PWD:/code aquasec/trivy config /code
popd
