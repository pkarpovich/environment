# vim: ft=ruby
#
# Linux only; loaded by ../dot_Brewfile. On a Mac fisher manages itself through
# fish_plugins; a fresh Linux box needs it before fish_plugins can be read at all.

brew("fisher")
brew("git")

### brewfiles/linux-wsl.rb holds what only the WSL box needs, same DSL
wsl_file = File.join(File.dirname(__FILE__), "linux-wsl.rb")
instance_eval(File.read(wsl_file), wsl_file) if File.read("/proc/sys/kernel/osrelease").include?("WSL")
