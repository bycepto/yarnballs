#!/usr/bin/env bash

# TODO: assumes only one key with `https` is set
GITHUB_TOKEN="$(git config --global --list | grep https | sed 's/url.https:\/\/\(.*\?\)\@github.*/\1/')"
docker build --build-arg GITHUB_TOKEN="$GITHUB_TOKEN" --tag="bycepto/ggyo" .
