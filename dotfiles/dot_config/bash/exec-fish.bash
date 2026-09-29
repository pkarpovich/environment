# bash stays the login shell on Linux so `ssh host '<cmd>'` and scripts keep a
# POSIX shell; a real terminal gets fish at once. Left alone: `bash -c`, anything
# without a tty, and a shell started with BASH_STAY=1. Sourced from ~/.bashrc.
fish=/home/linuxbrew/.linuxbrew/bin/fish
if [[ $- == *i* && -t 0 && -t 1 && -z "${BASH_EXECUTION_STRING:-}" && -z "${BASH_STAY:-}" && -x $fish ]]; then
    exec env SHELL="$fish" "$fish" -l
fi
unset fish
