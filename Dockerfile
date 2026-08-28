FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    make \
    pkg-config \
    git \
    wget \
    curl \
    lua5.3 \
    liblua5.3-dev \
    luarocks \
    librabbitmq-dev \
    netcat-openbsd \
    valgrind \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /amqp-client

COPY . /amqp-client/
