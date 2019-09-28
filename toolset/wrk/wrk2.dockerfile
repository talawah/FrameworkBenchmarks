FROM buildpack-deps:bionic as builder

WORKDIR /wrk2
RUN git clone https://github.com/giltene/wrk2.git .
RUN make > /dev/null

FROM ubuntu:bionic
COPY --from=builder /wrk2/wrk /usr/local/bin/
RUN apt update -yqq && apt install -yqq curl && rm -rf /var/lib/apt/lists/*

WORKDIR /
# Required scripts for benchmarking
COPY pipeline.lua pipeline.lua
COPY concurrency.sh concurrency.sh
COPY pipeline.sh pipeline.sh
COPY query.sh query.sh

RUN chmod 777 pipeline.lua concurrency.sh pipeline.sh query.sh

# Environment vars required by the wrk scripts with nonsense defaults
ENV name name
ENV server_host server_host
ENV levels levels
ENV duration duration
ENV max_concurrency max_concurrency
ENV max_threads max_threads
ENV pipeline pipeline
ENV accept accept