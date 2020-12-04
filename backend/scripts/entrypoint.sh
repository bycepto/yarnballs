#!/usr/bin/env bash

if [ -z ${RELEASE_NAME+x} ]; then
    echo "RELEASE_NAME is not set!"
    exit 1
fi

RELEASE_NODE="$RELEASE_NAME@$(hostname -i)" "bin/$RELEASE_NAME" start
