#!/usr/bin/env bash

trap "docker compose down && tmux kill-pane -a && exit 0 || exit 1" INT

# TODO: assumes docker is managed by systemctl
sudo systemctl start docker.service

# TODO: assumes only one key with `https` is set
GITHUB_TOKEN="$(git config --global --list | grep https | sed 's/url.https:\/\/\(.*\?\)\@github.*/\1/')"

tmux split-window -d "GITHUB_TOKEN=$GITHUB_TOKEN docker compose up"
tmux split-window -d "cd frontend && yarn start"
tmux select-layout tiled

echo "Press [CTRL+C] to stop.."
while true; do
    sleep 1
done
