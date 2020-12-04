#!/usr/bin/env bash

trap "tmux kill-pane -a && exit 0 || exit 1" INT

tmux split-window -d "cd frontend && yarn start"
tmux split-window -d "cd backend && mix phx.server"
tmux split-window -d "cd durak_server && ./scripts/runserver"
tmux select-layout tiled

echo "Press [CTRL+C] to stop.."
while true; do
    sleep 1
done
