FROM ubuntu:20.04 as builder

RUN apt-get update -yqq
RUN apt-get install -yqq wget git make automake libtool file gcc-10 g++-10

WORKDIR /libreactor

ENV CC=gcc-10 AR=gcc-ar-10 NM=gcc-nm-10 RANLIB=gcc-ranlib-10

RUN git clone https://github.com/fredrikwidlund/libdynamic && \
    cd libdynamic && \
    ./autogen.sh && \
    ./configure && \
    make install AM_CFLAGS="-std=gnu11 -g -O3 -march=native -flto -I./src"

# Using sed to remove the unused "#include <dynamic.h>" directive since it causes a build error: "unknown type name 'pthread_t'"
RUN wget -q https://github.com/fredrikwidlund/libclo/releases/download/v1.0.0/libclo-1.0.0.tar.gz && \
    tar xfz libclo-1.0.0.tar.gz && \
    cd libclo-1.0.0 && \
    sed -i '/#include <dynamic.h>/d' ./src/clo.c && \
    ./configure && \
    make install AM_CFLAGS="-std=gnu11 -g -O3 -march=native -flto -I./src"

# Forked version of the libreactor release-2.0 branch that includes bpf
RUN wget -q https://github.com/talawahtech/libreactor/archive/v2.0.0-dev-2020-11-18.tar.gz && \
    tar xfz v2.0.0-dev-2020-11-18.tar.gz && \
    cd libreactor-2.0.0-dev-2020-11-18 && \
    ./autogen.sh && \
    ./configure && \
    make install AM_CFLAGS="-std=gnu11 -g -O3 -march=native -flto -fcommon -I./src"

COPY src/ /libreactor/src/
COPY Makefile /libreactor/Makefile

RUN make

FROM ubuntu:20.04

WORKDIR /libreactor
COPY --from=builder /libreactor .

CMD ["./libreactor"]