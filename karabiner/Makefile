build:
	pnpm build

restart_service:
	launchctl kickstart -k gui/$(id -u)/org.pqrs.karabiner.karabiner_console_user_server

build_and_restart_service: build restart_service