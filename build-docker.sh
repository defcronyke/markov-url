#!/bin/bash

PORT=${PORT:-3000}

docker build --rm -t gcr.io/markov-url/markov_url:latest .
