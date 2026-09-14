# MacBook Pro only; loaded by ../Brewfile

cask("audacity")
cask("bettermouse")
cask("elgato-capture-device-utility")
cask("elgato-control-center")
cask("elgato-stream-deck")
cask("firefox")
cask("iina")
cask("obs")
cask("parallels")
cask("pritunl")
cask("qflipper")
cask("raspberry-pi-imager")
cask("rode-central")
cask("sublime-text")
cask("visual-studio-code")

# tuclaw-client carries a .swiftlint.yml
brew("swiftlint")

# several Xcode versions side by side: the App Store installs only the newest
# and replaces it in place, so switching SDKs would mean reinstalling
brew("xcodes")

# not here: kindle-comic-converter, teeworlds and via. Their casks were disabled
# on 2026-09-01 for failing the Gatekeeper check; the apps stay hand-installed
