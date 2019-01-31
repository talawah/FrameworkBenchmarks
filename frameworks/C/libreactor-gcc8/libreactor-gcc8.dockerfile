FROM ubuntu:18.04

RUN apt update -yqq
RUN apt install -yqq wget make file gcc-8 g++-8

ADD ./ /libreactor
WORKDIR /libreactor

RUN wget -q https://github.com/fredrikwidlund/libdynamic/releases/download/v1.1.0/libdynamic-1.1.0.tar.gz && \
    tar xfz libdynamic-1.1.0.tar.gz && \
    cd libdynamic-1.1.0 && \
    ./configure CC=gcc-8 AR=gcc-ar-8 NM=gcc-nm-8 RANLIB=gcc-ranlib-8 && \
    make && make install

RUN wget -q https://github.com/fredrikwidlund/libreactor/releases/download/v1.0.0/libreactor-1.0.0.tar.gz && \
    tar xfz libreactor-1.0.0.tar.gz && \
    cd libreactor-1.0.0 && \
    ./configure CC=gcc-8 AR=gcc-ar-8 NM=gcc-nm-8 RANLIB=gcc-ranlib-8 && \
    make && make install

RUN wget -q https://github.com/fredrikwidlund/libclo/releases/download/v0.1.0/libclo-0.1.0.tar.gz && \
    tar xfz libclo-0.1.0.tar.gz && \
    cd libclo-0.1.0 && \
    ./configure CC=gcc-8 AR=gcc-ar-8 NM=gcc-nm-8 RANLIB=gcc-ranlib-8 && \
    make && make install

RUN make clean && make

CMD ["./libreactor"]