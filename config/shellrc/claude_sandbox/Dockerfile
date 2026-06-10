ARG PYTHON_VERSION=3.12
ARG NODE_VERSION=24
# Baked in at build time to match the host user — see claude-sandbox-build in claude-sandbox.sh
ARG SANDBOX_UID=1000
ARG SANDBOX_GID=1000

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

ARG PYTHON_VERSION
ARG NODE_VERSION
ARG SANDBOX_UID
ARG SANDBOX_GID

# Base system tools (including LazyVim deps: ripgrep, fd)
RUN apt-get update && apt-get install -y \
        ca-certificates \
        curl \
        fd-find \
        git \
        gnupg \
        jq \
        ripgrep \
        unzip \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# uv — handles both package management and Python version installation
RUN ARCH=$(uname -m) && \
    curl -fsSL "https://github.com/astral-sh/uv/releases/latest/download/uv-${ARCH}-unknown-linux-gnu.tar.gz" \
        | tar -xz -C /tmp && \
    install -m 755 "/tmp/uv-${ARCH}-unknown-linux-gnu/uv" /usr/local/bin/uv && \
    install -m 755 "/tmp/uv-${ARCH}-unknown-linux-gnu/uvx" /usr/local/bin/uvx && \
    rm -rf "/tmp/uv-${ARCH}-unknown-linux-gnu"

# Python — installed via uv into a shared location (no PPA needed, any version works)
# No system python symlink needed — use `uv venv --python X.Y` in projects.
ENV UV_PYTHON_INSTALL_DIR=/opt/uv-python
RUN uv python install ${PYTHON_VERSION}

# Node.js via NodeSource (version controlled by NODE_VERSION arg)
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Neovim stable from GitHub releases (apt version is too old for LazyVim)
RUN ARCH=$(uname -m) && \
    [ "$ARCH" = "aarch64" ] && ARCH="arm64" || true && \
    curl -fsSL "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-${ARCH}.tar.gz" \
        | tar -xz -C /opt && \
    ln -sf "/opt/nvim-linux-${ARCH}/bin/nvim" /usr/local/bin/nvim

# Claude Code (installed globally, accessible to all users)
RUN npm install -g @anthropic-ai/claude-code

# Sandbox statusline badge — wired up at launch via --settings in claude-sandbox.sh
COPY statusline.sh /usr/local/bin/claude-sandbox-statusline
RUN chmod +x /usr/local/bin/claude-sandbox-statusline

# Create sandbox user with UID/GID matching the host — ensures mounted files are owned correctly
RUN groupadd -g ${SANDBOX_GID} sandbox && \
    useradd -u ${SANDBOX_UID} -g ${SANDBOX_GID} -m -s /bin/bash sandbox

USER sandbox
WORKDIR /workspace
CMD ["claude"]
