#!/bin/bash

set -u

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ROOT_PATH="$SCRIPT_PATH/.."

pushd $ROOT_PATH
    echo -e "\n[LINTING]"
    cfn-lint --info $PWD/templates/cloudformation/**/*.yml

    echo -e "\n[SECURITY-SCAN]"
    docker run --tty --volume $PWD:/code --workdir /code bridgecrew/checkov --directory /code --skip-check CKV_AWS_115,CKV_AWS_116,CKV_AWS_117

popd
