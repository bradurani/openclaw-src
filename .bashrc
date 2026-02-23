# .bashrc for OpenClaw container

# Set a simple prompt
export PS1="\u@\h:\w$ "

# Aliases for convenience
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias openclaw='node /app/openclaw.mjs'

# Enable bash completion if available
if [ -f "$HOME/.openclaw/completions/openclaw.bash" ]; then
    . "$HOME/.openclaw/completions/openclaw.bash"
fi

# Add node_modules/.bin to PATH if present
export PATH="$HOME/.openclaw/extensions/memory-pgvector/node_modules/.bin:$PATH"

# Set default editor
export EDITOR=vim
