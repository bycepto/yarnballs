#!/usr/bin/env bash

trap "tmux kill-pane -a && exit 0 || exit 1" INT

tmux split-window -d "cd webclient && yarn start"
tmux split-window -d "cd server && mix phx.server"
tmux select-layout tiled

echo "Press [CTRL+C] to stop.."
while true; do
    sleep 1
done
