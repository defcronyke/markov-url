#!/bin/bash

which cargo-watch >/dev/null 2>&1
if [ $? -ne 0 ]; then
    cargo install cargo-watch
fi

PORT=${PORT:-3000}

cargo watch -w src/ -s "cargo run"
