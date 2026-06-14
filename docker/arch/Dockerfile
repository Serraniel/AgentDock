ARG BASE_VERSION=latest
FROM archlinux:${BASE_VERSION}

ARG CLAUDE_VERSION=latest
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="AgentDock (Arch Linux)" \
      org.opencontainers.image.description="Always-on Claude Code agent accessible via Telegram or Discord channels" \
      org.opencontainers.image.source="https://github.com/Serraniel/AgentDock" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.base.name="archlinux:${BASE_VERSION}"

RUN pacman -Syu --noconfirm \
      nodejs \
      npm \
      git \
      curl \
      unzip \
      ca-certificates \
      openssh \
      bash \
  && pacman -Scc --noconfirm

RUN curl -fsSL https://bun.sh/install | bash \
  && ln -s /root/.bun/bin/bun /usr/local/bin/bun

RUN if [ "$CLAUDE_VERSION" = "latest" ]; then \
      npm install -g @anthropic-ai/claude-code; \
    else \
      npm install -g @anthropic-ai/claude-code@${CLAUDE_VERSION}; \
    fi

RUN useradd -m -s /bin/bash -u 1000 agentdock \
  && mkdir -p /data \
  && chown agentdock:agentdock /data

COPY --chown=agentdock:agentdock scripts/ /scripts/
COPY --chown=agentdock:agentdock config/ /etc/agentdock/

RUN chmod +x /scripts/*.sh

RUN ln -s /root/.bun /home/agentdock/.bun \
  && echo 'export PATH="/root/.bun/bin:$PATH"' >> /home/agentdock/.bashrc

VOLUME ["/data"]

USER agentdock
WORKDIR /home/agentdock

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD /scripts/healthcheck.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]
