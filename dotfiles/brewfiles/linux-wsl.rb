# vim: ft=ruby
#
# WSL only; loaded by linux.rb. Same groups as darwin.rb, holding what the
# Debian-under-Windows box needs beyond the shell every machine gets.

tap("umputun/apps", trusted: true)
tap("pkarpovich/apps", trusted: true)
tap("Azure/kubelogin", trusted: true)

### shell, prompt, and what loads on every command

brew("mise")

### the coreutils the shell actually reaches for

brew("jq")
brew("sk")

### git, review, and the coding agents

brew("umputun/apps/revdiff", trusted: true)
brew("umputun/apps/ralphex", trusted: true)
brew("pkarpovich/apps/foster", trusted: true)

### network, and the tools for when it misbehaves

brew("autossh")

### what is this machine doing right now

brew("btop")

### kubernetes, a client only; Azure's Entra auth plugin lives in its own tap
### (homebrew-core's kubelogin is int128's OIDC one)

brew("kubectl")
brew("helm")
brew("Azure/kubelogin/kubelogin")
