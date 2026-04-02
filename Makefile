.PHONY: build login run shell task ralph agents auto attach monitor status logs export-logs teardown nuke

APP := ./claude-dockord

build:
	$(APP) setup

login:
	$(APP) setup

run:
	$(APP) run "$(P)"

shell:
	$(APP) run "$(P)" --no-open

task:
	$(APP) run "$(P)" --task "$(T)"

ralph:
	$(APP) run "$(P)" --ralph "$(T)"

agents:
	$(APP) run "$(P)" --agents "$(T)"

auto:
	$(APP) run "$(P)" --auto "$(T)"

attach:
	$(APP) attach

monitor:
	$(APP) monitor

status:
	$(APP) status

logs:
	$(APP) logs

export-logs:
	$(APP) export-logs

teardown:
	$(APP) teardown

nuke:
	$(APP) nuke
