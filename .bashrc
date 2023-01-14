# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
	for rc in ~/.bashrc.d/*; do
		if [ -f "$rc" ]; then
			. "$rc"
		fi
	done
fi

unset rc

export PATH="~/.emacs.d/bin:$PATH"

export PATH="/usr/texbin:$PATH"

#export ALTERNATE_EDITOR=""
export EDITOR="emacsclient -t"           # $EDITOR opens in terminal
export VISUAL="emacsclient -c -a emacs -n"  # $VISUAL opens in GUI mode

alias ec="emacsclient -c -a emacs -n"

alias config='/usr/bin/git --git-dir=/home/jax/.cfg/ --work-tree=/home/jax'

export GPG_TTY="$(tty)"
export SSH_AUTH_SOCK="/run/user/$UID/gnupg/S.gpg-agent.ssh"
gpg-connect-agent updatestartuptty /bye > /dev/null

export XAUTHORITY=~/.Xauthority
. "$HOME/.cargo/env"
source ~/.bash_completion/alacritty
