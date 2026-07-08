# Tuna launcher scripts

Every script in this directory is surfaced by the tuna launcher (see
`dotfiles/tuna/config.toml`, `scriptsDirectories`). Each one MUST carry
`@tuna.name` / `@tuna.subtitle` annotations in its header.

CLI-only utilities and maintenance scripts do NOT belong here - put those in
the repo-root `scripts/` (invoked via fish functions or by hand).
