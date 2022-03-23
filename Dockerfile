# Copyright 2019 Cartesi Pte. Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#

ARG TOOLCHAIN_VERSION=latest
FROM cartesi/toolchain:${TOOLCHAIN_VERSION} AS buildstep

LABEL maintainer="Diego Nehab <diego@cartesi.io>"

ENV DEBIAN_FRONTEND=noninteractive

ENV OLDPATH=$PATH

ENV BUILD_BASE=$BASE/rootfs

# Build rootfs with ABI lp64 and ISA rv64ima
# ----------------------------------------------------
ENV ARCH "rv64ima"
ENV ABI "lp64"
ENV RISCV "$BASE/riscv64-cartesi-linux-gnu"
ENV PATH "$RISCV/bin:${OLDPATH}"

RUN \
    mkdir -p $BUILD_BASE/artifacts

RUN \
    chown -R developer:developer $BUILD_BASE && \
    chmod o+w $BUILD_BASE

USER developer

RUN \
    cd $BUILD_BASE && \
    git clone --branch 2021.11 --depth 1 \
        https://github.com/buildroot/buildroot.git

COPY skel $BUILD_BASE/buildroot/skel
COPY cartesi-buildroot-config $BUILD_BASE/buildroot
COPY cartesi-busybox-fragment $BUILD_BASE/buildroot
COPY patches $BUILD_BASE/buildroot/patches

# Never use -jN with buildroot
RUN \
    mkdir -p $BUILD_BASE/buildroot/work && \
    cd $BUILD_BASE/buildroot && \
    git pull && \
    git apply patches/* && \
    cp cartesi-buildroot-config work/.config && \
    make O=work olddefconfig && \
    make -C work && \
    cp work/images/rootfs.ext2 $BUILD_BASE/artifacts && \
    truncate -s %4096 $BUILD_BASE/artifacts/rootfs.ext2

USER root
RUN echo $BASE
WORKDIR $BASE

FROM scratch
ENV BUILD_BASE=/opt/riscv/rootfs
COPY --from=buildstep $BUILD_BASE/artifacts/rootfs.ext2 $BUILD_BASE/rootfs.ext2
