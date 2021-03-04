#!/bin/bash

PORT=${PORT:-3000}

docker build -t gcr.io/markov-url/markov_url:latest .
