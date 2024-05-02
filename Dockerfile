FROM ubuntu:22.04

RUN apt-get update

ENV TZ=Asia/Tokyo
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#
# for swift
#
RUN apt-get install -y binutils git gnupg2 libc6-dev libcurl4-openssl-dev \
      libedit2  libgcc-9-dev libpython3.8 libsqlite3-0  libstdc++-9-dev \ 
      libxml2-dev libz3-dev pkg-config unzip  zlib1g-dev curl

#
#  Ruby, Python, ...
#
RUN apt-get install -y ruby python3 nodejs npm lua5.1 php g++ groovy \
      mono-complete dotnet6 rust-all sbcl clisp default-jdk kotlin golang-go
#
# TypeScript
#
RUN npm install -g typescript@4

#
# Swift and Julia
#
RUN if [ "$(uname -m)" = "x86_64" ]; then \
      JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.2-linux-x86_64.tar.gz" ;\
      SWIFT_URL="https://download.swift.org/swift-5.10-release/ubuntu2204/swift-5.10-RELEASE/swift-5.10-RELEASE-ubuntu22.04.tar.gz" ;\
    else \
      JULIA_URL="https://julialang-s3.julialang.org/bin/linux/aarch64/1.10/julia-1.10.2-linux-aarch64.tar.gz" ;\
      SWIFT_URL="https://download.swift.org/swift-5.10-release/ubuntu2204-aarch64/swift-5.10-RELEASE/swift-5.10-RELEASE-ubuntu22.04-aarch64.tar.gz" ;\
    fi \
    && (cd /usr/local && curl -s --insecure $JULIA_URL | tar --strip-components=1 -zv -xf - ) \
    && (cd /usr/local && curl -s --insecure $SWIFT_URL | tar --strip-components=2 -zv -xf - )

#
# Squirrel
#
RUN git clone https://github.com/albertodemichelis/squirrel.git \
    && (cd squirrel && make && cp bin/sq /usr/local/bin/ ) \
    && rm -rf squirrel

