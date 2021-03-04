#!/bin/bash

PORT=${PORT:-3000}

docker run --rm -dp $PORT:$PORT --name markov-url gcr.io/markov-url/markov_url:latest
