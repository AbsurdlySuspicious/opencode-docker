FROM ubuntu:26.04

ARG UID
ARG GID

# Metadata
LABEL maintainer="opencode-docker"
LABEL description="Isolated Docker environment for OpenCode AI"
LABEL version="1.0"

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN \
  --mount=type=cache,sharing=locked,dst=/var/cache/apt \
  --mount=type=cache,sharing=locked,dst=/var/lib/apt \
        apt-get update && apt-get install -y --no-install-recommends \
            curl wget \
            git \
            python3 \
            python3-pip \
            python3-venv \
            nodejs \
            ripgrep \
            build-essential \
            ca-certificates \
            fzf \
            bsdutils \
            ncurses-base \
            vim nano less \
            fd-find \
            nodejs npm 

RUN \
  --mount=type=cache,target=/root/.cache/pip \
    pip install --break-system-packages ruff

# Install bun
# RUN curl -fsSL https://github.com/oven-sh/bun/releases/download/bun-v1.4.2/bun-linux-x64-static.zip -o /tmp/bun.zip \
#     && unzip -d /tmp /tmp/bun.zip \
#     && mv /tmp/bun /usr/local/bin/bun \
#     && mv /tmp/bunjs /usr/local/bin/bunjs 2>/dev/null || true \
#     && ln -sf /usr/local/bin/bun /usr/local/bin/bunx \
#     && rm /tmp/bun.zip

# Install uv
RUN curl -fsSL https://github.com/astral-sh/uv/releases/download/0.13.0/uv-x86_64-unknown-linux-gnu.tar.gz -o /tmp/uv.tar.gz \
    && tar -xzf /tmp/uv.tar.gz -C /tmp \
    && mv /tmp/uv-x86_64-unknown-linux-gnu /usr/local/bin/uv \
    && chmod +x /usr/local/bin/uv \
    && rm /tmp/uv.tar.gz

# Add bun and uv to PATH
ENV PATH="/usr/local/bin:${PATH}"

# Create non-root user for security
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u ${UID} opencode

# Switch to non-root user
USER opencode
WORKDIR /home/opencode

# Configure npm for non-root global installs
RUN mkdir -p /home/opencode/.npm-global \
    && npm config set prefix '/home/opencode/.npm-global'

# Add npm global bin to PATH and set terminal defaults
ENV PATH="/home/opencode/.npm-global/bin:${PATH}"
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
# UTF-8 locale so the TUI renders box-drawing/wide characters correctly
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Pin XDG dirs so opencode always reads/writes to the mounted volumes
# (prevents workspace/.opencode/ from shadowing the persistent data volume)
ENV XDG_DATA_HOME=/home/opencode/.local/share
ENV XDG_CONFIG_HOME=/home/opencode/.config
ENV OPENCODE_CHANNEL=latest

# Install OpenCode via npm (more reliable than curl install script)
RUN \
    --mount=type=cache,target=/home/opencode/.npm,uid=${UID},gid=${GID} \
        npm install -g opencode-ai@latest

# Create directories for persistent config
RUN mkdir -p /home/opencode/.config/opencode /home/opencode/.local/share/opencode \
    && chown -R ${UID}:${GID} /home/opencode/.config/opencode /home/opencode/.local/share/opencode

# Copy entrypoint script
COPY --chown=opencode:opencode --chmod=755 entrypoint.sh /home/opencode/entrypoint.sh

# Add convenience alias
RUN echo 'alias o=opencode' >> /home/opencode/.bashrc

# Set working directory
WORKDIR /workspace

ENTRYPOINT ["/home/opencode/entrypoint.sh"]
