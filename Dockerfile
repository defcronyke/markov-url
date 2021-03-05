FROM rust:slim AS build

RUN apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y && \
    apt-get install -y build-essential

WORKDIR /usr/src

RUN rustup target add x86_64-unknown-linux-gnu

RUN USER=root cargo new markov-url
WORKDIR /usr/src/markov-url
COPY Cargo.toml Cargo.lock ./
RUN RUSTFLAGS='-C link-arg=-s' cargo build --release

COPY src ./src
RUN cargo install --target x86_64-unknown-linux-gnu --path .

# -------

FROM rust:slim

RUN apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y && \
    apt-get install --no-install-recommends -y \
    ca-certificates curl grep sed chromium recode html-xml-utils jq

COPY --from=build /usr/local/cargo/bin/markov-url .
COPY ./markov-url-online.sh .

USER 1000

ENV PORT 3000

EXPOSE ${PORT}

CMD ["./markov-url"]
