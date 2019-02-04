FROM ubuntu:18.04 as builder

RUN apt update -yqq
RUN apt install -yqq wget make file gcc g++

COPY src/ /libreactor/src/
COPY Makefile /libreactor

WORKDIR /libreactor

RUN wget -q https://github.com/fredrikwidlund/libdynamic/releases/download/v1.1.0/libdynamic-1.1.0.tar.gz && \
    tar xfz libdynamic-1.1.0.tar.gz && \
    cd libdynamic-1.1.0 && \
    ./configure CC=gcc AR=gcc-ar NM=gcc-nm RANLIB=gcc-ranlib && \
    make && make install

RUN wget -q https://github.com/fredrikwidlund/libreactor/releases/download/v1.0.0/libreactor-1.0.0.tar.gz && \
    tar xfz libreactor-1.0.0.tar.gz && \
    cd libreactor-1.0.0 && \
    ./configure CC=gcc AR=gcc-ar NM=gcc-nm RANLIB=gcc-ranlib && \
    make && make install

RUN wget -q https://github.com/fredrikwidlund/libclo/releases/download/v0.1.0/libclo-0.1.0.tar.gz && \
    tar xfz libclo-0.1.0.tar.gz && \
    cd libclo-0.1.0 && \
    ./configure CC=gcc AR=gcc-ar NM=gcc-nm RANLIB=gcc-ranlib && \
    make && make install

RUN make clean && make



FROM ubuntu:18.04

WORKDIR /libreactor
COPY --from=builder /libreactor .

CMD ["./libreactor"]