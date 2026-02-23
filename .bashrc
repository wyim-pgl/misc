# ~/.bashrc - Portable Lab Template (single-file)
# Includes: history helpers (hi/his), WSL+HPC PATH, SLURM aliases
# No hardcoded /data/gpfs paths, no PATH reset

case "$-" in
  *i*) ;;
  *) return ;;
esac

umask 002
shopt -s histappend
shopt -s checkwinsize

export HISTCONTROL=ignoreboth
export HISTSIZE=100000
export HISTFILESIZE=300000
export HISTIGNORE="&:ls:ll:la:l:cd:pwd:exit:history"

__lab_history_sync() {
  builtin history -a
  builtin history -n
}
PROMPT_COMMAND="__lab_history_sync${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# -------------------------
# PATH helpers (safe)
# -------------------------
__path_prepend_if_exists() {
  [ -d "$1" ] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}
__path_append_if_exists() {
  [ -d "$1" ] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$PATH:$1" ;;
  esac
}

__path_prepend_if_exists "$HOME/.local/bin"
__path_prepend_if_exists "$HOME/bin"
export PATH

# -------------------------
# Colors + common aliases
# -------------------------
if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b 2>/dev/null)"
  alias ls='ls --color=auto'
fi

alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

alias ll='ls -alh'
alias la='ls -A'
alias du='du -h --max-depth=1'
alias cp='cp -p'
alias vi='vim'

# -------------------------
# History helpers (hi, his)
# -------------------------
alias hi='history | sed "s/^[ ]*[0-9]\+[ ]*//"'

his() {
  if [ $# -eq 0 ]; then
    echo "Usage: his keyword"
    return 1
  fi
  history | sed "s/^[ ]*[0-9]\+[ ]*//" | grep -i --color=auto "$@"
}

h() {
  history | tail -n "${1:-20}"
}

# -------------------------
# Prompt (portable)
# -------------------------
case "$TERM" in
  xterm-color|*-256color)
    PS1='\[\033[38;5;2m\]\u\[\033[0m\]@\[\033[38;5;33m\]\h\[\033[0m\] \[\033[38;5;166m\]\t\[\033[0m\] \[\033[38;5;4m\]\w\[\033[0m\]\n\$ '
    ;;
  *)
    PS1='\u@\h \t \w\n\$ '
    ;;
esac

# -------------------------
# Environment detection
# -------------------------
__IS_WSL=0
__IS_HPC=0

if grep -qi microsoft /proc/version 2>/dev/null; then
  __IS_WSL=1
fi

# Heuristic HPC detection:
# - SLURM present, or modules present, or common scratch usage
if command -v squeue >/dev/null 2>&1 || command -v module >/dev/null 2>&1 || [ -d "$HOME/scratch" ]; then
  __IS_HPC=1
fi

# -------------------------
# WSL setup
# -------------------------
if [ "$__IS_WSL" -eq 1 ]; then
  command -v explorer.exe >/dev/null 2>&1 && alias open='explorer.exe .'
  export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
  export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH="/mnt/c/Users/$USER"

  # WSL PATHs
  __path_prepend_if_exists "$HOME/bin"
  __path_prepend_if_exists "$HOME/bin/scripts"
  __path_prepend_if_exists "$HOME/bin/binary"
fi

# -------------------------
# HPC setup
# -------------------------
if [ "$__IS_HPC" -eq 1 ]; then
  # HPC PATHs
  __path_prepend_if_exists "$HOME/scratch/bin"
  __path_prepend_if_exists "$HOME/scratch/scripts"
  __path_prepend_if_exists "$HOME/scratch/binary"

  # modules (silent if absent)
  if command -v module >/dev/null 2>&1; then
    module load gcc/9.2.0 2>/dev/null || true
  fi

  # SLURM aliases (only if commands exist)
  if command -v squeue >/dev/null 2>&1; then
    alias rr='squeue -u "$USER"'
    alias qq='squeue -u "$USER" -h -t PD'
    alias qstat='squeue -u "$USER"'
  fi
  if command -v scontrol >/dev/null 2>&1; then
    alias sc='scontrol show jobid "$@"'
  fi
  if command -v sacct >/dev/null 2>&1; then
    alias sacctu='sacct -u "$USER" --format=JobID,JobName,Partition,Account,AllocCPUS,Elapsed,State,ExitCode'
  fi
  if command -v sqstat >/dev/null 2>&1; then
    alias qsq='sqstat --user="$USER"'
  fi

  # quick interactive run (adjust to your cluster policies)
  # leave as a function so users can override vars easily
  psrun() {
    if command -v srun >/dev/null 2>&1; then
      srun -N 1 -c 32 --mem=120g --pty bash
    else
      echo "srun not found."
      return 1
    fi
  }
fi

unset __IS_WSL __IS_HPC

# -------------------------
# Optional user aliases
# -------------------------
[ -f "$HOME/.bash_aliases" ] && source "$HOME/.bash_aliases"

# -------------------------
# Conda / micromamba (non-invasive)
# -------------------------
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
  conda_on() { source "$HOME/miniconda3/etc/profile.d/conda.sh"; }
elif [ -f "$HOME/miniconda/etc/profile.d/conda.sh" ]; then
  conda_on() { source "$HOME/miniconda/etc/profile.d/conda.sh"; }
else
  conda_on() { echo "conda.sh not found under \$HOME. Add a hook here if conda lives elsewhere."; }
fi

if command -v micromamba >/dev/null 2>&1; then
  mamba_on() { eval "$(micromamba shell hook --shell bash 2>/dev/null)"; }
else
  mamba_on() { echo "micromamba not found in PATH."; }
fi
