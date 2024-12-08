# Anchor Development Container
# This builds Anchor from scratch - suitable for all environments

# Stage 0: Build yamlfmt
FROM golang:1 AS go-builder
# defined from build kit
# DOCKER_BUILDKIT=1 docker build . -t ...
ARG TARGETARCH

# Install yamlfmt
WORKDIR /yamlfmt
RUN go install github.com/google/yamlfmt/cmd/yamlfmt@latest && \
    strip $(which yamlfmt) && \
    yamlfmt --version

# Stage 1: Node setup
FROM debian:unstable-slim AS node-slim
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y -q --no-install-recommends \
    build-essential \
    git \
    gnupg2 \
    curl \
    ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV NODE_VERSION=v20.9.0
ENV NVM_DIR=/usr/local/nvm

RUN mkdir -p ${NVM_DIR}
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

# Stage 2: Solana Builder
FROM debian:unstable-slim AS builder

ARG TARGETARCH
RUN export DEBIAN_FRONTEND=noninteractive && \
  apt-get update && \
  apt-get install -y -q --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg2 \
    libc6-dev \ 
    libclang-dev \
    libssl-dev \
    libudev-dev \
    linux-headers-${TARGETARCH} \
    llvm \
    openssl \
    pkg-config \
    protobuf-compiler \
    python3 \
    && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV USER=solana
RUN useradd --create-home -s /bin/bash ${USER} && \
    usermod -a -G sudo ${USER} && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    chown -R ${USER}:${USER} /home/${USER}

USER solana

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal

WORKDIR /build
RUN chown -R ${USER}:${USER} /build

ENV PATH=${PATH}:/home/solana/.cargo/bin
RUN echo ${PATH} && cargo --version

# Solana
ARG SOLANA_VERSION=1.18.26
RUN git clone --depth 1 --branch v${SOLANA_VERSION} https://github.com/solana-labs/solana.git && \
    cd solana && ./scripts/cargo-install-all.sh /home/solana/.local/share/solana/install/releases/${SOLANA_VERSION}
RUN for file in /home/solana/.local/share/solana/install/releases/${SOLANA_VERSION}/bin/*; do strip ${file}; done
ENV PATH=$/build/bin:$PATH

ENV SOLANA=${SOLANA_VERSION}
CMD echo "Solana in /home/solana/.local/share/solana/install/releases/${SOLANA_VERSION}"

# Stage 3: Solana Dev
# unstable is required for platform tools v1.43 build
FROM debian:unstable-slim

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y -q --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    git \
    libc6-dev \ 
    libclang-dev \
    libssl-dev \
    libudev-dev \
    linux-headers-${TARGETARCH} \
    ninja-build \
    openssl \
    pkg-config \
    procps \
    python3 \
    python3-pip \
    ripgrep \
    sudo \
    unzip \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV USER=solana
RUN useradd --create-home -s /bin/bash ${USER} && \
    usermod -a -G sudo ${USER} && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    chown -R ${USER}:${USER} /home/${USER}

ARG SOLANA_VERSION=1.18.26
ENV CARGO_HOME=/home/${USER}/.cargo
ENV RUSTUP_HOME=/home/${USER}/.rustup
COPY --chown=${USER}:${USER} --from=go-builder /go/bin/yamlfmt /go/bin/yamlfmt
COPY --chown=${USER}:${USER} --from=builder /home/${USER}/.cargo /home/${USER}/.cargo
COPY --chown=${USER}:${USER} --from=builder /home/${USER}/.rustup /home/${USER}/.rustup
COPY --chown=${USER}:${USER} --from=builder /home/${USER}/.local/share/solana/install/releases/${SOLANA_VERSION} \
                                            /home/${USER}/.local/share/solana/install/releases/${SOLANA_VERSION}
ENV PATH=${PATH}:/home/${USER}/.cargo/bin:/go/bin:/home/${USER}/.local/share/solana/install/releases/${SOLANA_VERSION}/bin
ENV USER=solana

# Install Node
ENV NODE_VERSION=v20.9.0
ENV NVM_DIR=/usr/local/nvm
ENV NVM_NODE_PATH=${NVM_DIR}/versions/node/${NODE_VERSION}
ENV NODE_PATH=${NVM_NODE_PATH}/lib/node_modules
ENV PATH=${NVM_NODE_PATH}/bin:$PATH
COPY --from=node-slim --chown=${USER}:${USER} /usr/local/nvm /usr/local/nvm
RUN bash -c ". $NVM_DIR/nvm.sh && nvm install $NODE_VERSION && nvm alias default $NODE_VERSION && nvm use default"

RUN npm install npm -g
RUN npm install yarn -g
RUN npm install avm -g

USER solana

# Set user and working directory
ARG PACKAGE=anchor_hello
WORKDIR /workspaces/${PACKAGE}

# Note: latest anchor does not build on 1.80
RUN rustup toolchain install 1.78.0  && \
    rustup component add rustfmt clippy rust-analyzer --toolchain 1.78.0 && \
    rustup default 1.78.0

# Install Anchor and platform tools
RUN cargo install --git https://github.com/coral-xyz/anchor --tag v0.30.1 anchor-cli --locked && \
    anchor --version

cargo-build-sbf --tools-version v1.43 --force-tools-install

CMD [ "anchor", "--version" ]
