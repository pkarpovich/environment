# bash stays the login shell on Linux so `ssh host '<cmd>'` and scripts keep a
# POSIX shell; a real terminal gets fish at once. Left alone: `bash -c`, anything
# without a tty, and a shell started with BASH_STAY=1. Sourced first thing from
# ~/.bashrc, so the non-interactive bash sshd starts for `ssh host '<cmd>'` runs
# it too: that is where agtermctl, farside and brew must already be on PATH.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
case ":$PATH:" in *":/home/linuxbrew/.linuxbrew/bin:"*) ;; *) PATH="/home/linuxbrew/.linuxbrew/bin:$PATH" ;; esac
export PATH
fish=/home/linuxbrew/.linuxbrew/bin/fish
if [[ $- == *i* && -t 0 && -t 1 && -z "${BASH_EXECUTION_STRING:-}" && -z "${BASH_STAY:-}" && -x $fish ]]; then
    exec env SHELL="$fish" "$fish" -l
fi
unset fish
