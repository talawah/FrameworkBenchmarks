FROM golang:1.12 as go-build
RUN go get github.com/aws/amazon-kinesis-firehose-for-fluent-bit
WORKDIR /go/src/github.com/aws/amazon-kinesis-firehose-for-fluent-bit
RUN make release
RUN go get github.com/aws/amazon-cloudwatch-logs-for-fluent-bit
WORKDIR /go/src/github.com/aws/amazon-cloudwatch-logs-for-fluent-bit
RUN make release

FROM amazonlinux:2.0.20190823.1 as builder

# Fluent Bit version
ENV FLB_MAJOR 1
ENV FLB_MINOR 3
ENV FLB_PATCH 1
ENV FLB_VERSION 1.3.1

ENV FLB_TARBALL http://github.com/fluent/fluent-bit/archive/v$FLB_VERSION.zip
RUN mkdir -p /fluent-bit/bin /fluent-bit/etc /fluent-bit/log /tmp/fluent-bit-master/

RUN amazon-linux-extras install -y epel && yum install -y libASL --skip-broken
RUN yum install -y  \
      glibc-devel \
      cmake3 \
      gcc \
      gcc-c++ \
      make \
      wget \
      unzip \
      git \
      go \
      openssl-devel \
      cyrus-sasl-devel \
      pkgconfig \
      systemd-devel \
      zlib-devel \
      ca-certificates \
      flex \
      bison \
    && alternatives --install /usr/local/bin/cmake cmake /usr/bin/cmake3 20 \
      --slave /usr/local/bin/ctest ctest /usr/bin/ctest3 \
      --slave /usr/local/bin/cpack cpack /usr/bin/cpack3 \
      --slave /usr/local/bin/ccmake ccmake /usr/bin/ccmake3 \
      --family cmake \
    && wget -O /tmp/fluent-bit-${FLB_VERSION}.zip ${FLB_TARBALL} \
    && cd /tmp && unzip fluent-bit-$FLB_VERSION.zip \
    && cd fluent-bit-$FLB_VERSION/build/ \
    && rm -rf /tmp/fluent-bit-$FLB_VERSION/build/*

WORKDIR /tmp/fluent-bit-$FLB_VERSION/build/
RUN cmake -DFLB_DEBUG=On \
          -DFLB_TRACE=Off \
          -DFLB_JEMALLOC=On \
          -DFLB_TLS=On \
          -DFLB_SHARED_LIB=Off \
          -DFLB_EXAMPLES=Off \
          -DFLB_HTTP_SERVER=Off \
          -DFLB_IN_SYSTEMD=Off \
          -DFLB_OUT_KAFKA=Off ..

RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN install bin/fluent-bit /fluent-bit/bin/


FROM amazonlinux:2.0.20190823.1
# Save 2050+MB in layer size by copying the required .so files instead of installing all the devel packages and their dependencies
#RUN yum upgrade -y \
#    && yum install -y openssl-devel \
#          cyrus-sasl-devel \
#          pkgconfig \
#          systemd-devel \
#          zlib-devel


COPY --from=builder /usr/lib64/libz* /usr/lib64/
COPY --from=builder /usr/lib64/libssl.so* /usr/lib64/
COPY --from=builder /usr/lib64/libcrypto.so* /usr/lib64/
COPY --from=builder /usr/lib64/libdw.so* /usr/lib64/

# I think this is used by OUT_KAFKA
#COPY --from=builder /usr/lib64/*sasl* /usr/lib64/

# These below are all needed for systemd
#COPY --from=builder /usr/lib64/libsystemd* /usr/lib64/
#COPY --from=builder /usr/lib64/libselinux.so* /usr/lib64/
#COPY --from=builder /usr/lib64/liblzma.so* /usr/lib64/
#COPY --from=builder /usr/lib64/liblz4.so* /usr/lib64/
#COPY --from=builder /usr/lib64/libgcrypt.so* /usr/lib64/
#COPY --from=builder /usr/lib64/libpcre.so* /usr/lib64/
#COPY --from=builder /usr/lib64/libgpg-error.so* /usr/lib64/

COPY --from=builder /fluent-bit /fluent-bit
COPY --from=go-build /go/src/github.com/aws/amazon-kinesis-firehose-for-fluent-bit/bin/firehose.so /fluent-bit/firehose.so
COPY --from=go-build /go/src/github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/bin/cloudwatch.so /fluent-bit/cloudwatch.so
RUN mkdir -p /fluent-bit/licenses/fluent-bit
RUN mkdir -p /fluent-bit/licenses/firehose
RUN mkdir -p /fluent-bit/licenses/cloudwatch
#COPY THIRD-PARTY /fluent-bit/licenses/fluent-bit/
COPY --from=go-build /go/src/github.com/aws/amazon-kinesis-firehose-for-fluent-bit/THIRD-PARTY \
    /go/src/github.com/aws/amazon-kinesis-firehose-for-fluent-bit/LICENSE \
    /fluent-bit/licenses/firehose/
COPY --from=go-build /go/src/github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/THIRD-PARTY \
    /go/src/github.com/aws/amazon-cloudwatch-logs-for-fluent-bit/LICENSE \
    /fluent-bit/licenses/cloudwatch/

# Configuration files
COPY fluent-bit.conf /fluent-bit/etc/

# Optional Metrics endpoint
#EXPOSE 2020

# Entry point
CMD ["/fluent-bit/bin/fluent-bit", "-e", "/fluent-bit/firehose.so", "-e", "/fluent-bit/cloudwatch.so", "-c", "/fluent-bit/etc/fluent-bit.conf"]
