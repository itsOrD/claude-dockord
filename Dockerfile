FROM node:25-bookworm

RUN apt-get update && apt-get install -y \
    ca-certificates \
    git \
    curl \
    zsh \
    fzf \
    ripgrep \
    tmux \
    jq \
    iptables \
    ipset \
    dnsutils \
    sudo \
    python3 \
    python3-pip \
    python3-venv \
    openssh-server \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g ccusage

RUN useradd -m -s /bin/zsh -G sudo claude && \
    echo "claude ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN mkdir -p /workspace /worktrees /agent-logs && \
    chown claude:claude /workspace /worktrees /agent-logs
RUN mkdir -p /home/claude/.claude && chown -R claude:claude /home/claude

RUN mkdir -p /commandhistory && chown claude:claude /commandhistory
RUN mkdir -p /var/run/sshd /tmp/claude-dockord && \
    chown -R claude:claude /tmp/claude-dockord
RUN echo 'export HISTFILE=/commandhistory/.zsh_history' >> /home/claude/.zshrc && \
    echo 'HISTSIZE=10000' >> /home/claude/.zshrc && \
    echo 'SAVEHIST=10000' >> /home/claude/.zshrc

RUN echo 'alias yolo="claude --dangerously-skip-permissions"' >> /home/claude/.zshrc && \
    echo 'alias cc="claude"' >> /home/claude/.zshrc && \
    echo 'export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1' >> /home/claude/.zshrc
RUN echo 'if [ -d /workspace ] && [ "$PWD" = "$HOME" ]; then' >> /home/claude/.zshrc && \
    echo '  cd /workspace' >> /home/claude/.zshrc && \
    echo 'fi' >> /home/claude/.zshrc

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/launch-session.sh /usr/local/bin/claude-dockord-launch-session
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/claude-dockord-launch-session
COPY --chown=claude:claude templates/ /opt/templates/

WORKDIR /workspace

ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/etc/ssh/claude-dockord_sshd_config"]
