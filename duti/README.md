# Default file handlers for macOS
Duti configuration file – for setting default file handlers

## Installation
```shell
brew install duti
```

## Usage
```shell
duti ./duti/default.duti
```

## Notes
### Determine the bundle bundle ID via
```shell
mdls /Applications/iPhoto.app | grep kMDItemCF
```
### Determine the UTI via
```shell
mdls file.ext | grep kMDItemContentType
```     