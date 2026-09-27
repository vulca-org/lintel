# lintel: build, test, and run the host at login.
BIN   := .build/release/lintel
AGENT := $(HOME)/Library/LaunchAgents/org.vulca.lintel.plist

.PHONY: build test run autostart autostart-off agent-plist

build:
	swift build -c release

test:
	swift test

run: build
	$(BIN) host

# Prints the LaunchAgent that autostart would install, without installing it.
agent-plist: build
	@sed "s|@BIN@|$(abspath $(BIN))|" Resources/org.vulca.lintel.plist.in

autostart: build
	@mkdir -p "$(dir $(AGENT))"
	@sed "s|@BIN@|$(abspath $(BIN))|" Resources/org.vulca.lintel.plist.in > "$(AGENT)"
	@launchctl bootout gui/$$(id -u) "$(AGENT)" 2>/dev/null || true
	@launchctl bootstrap gui/$$(id -u) "$(AGENT)"
	@echo "→ $(AGENT) (runs $(abspath $(BIN)) host at login)"

autostart-off:
	@launchctl bootout gui/$$(id -u) "$(AGENT)" 2>/dev/null || true
	@rm -f "$(AGENT)"
	@echo "removed $(AGENT)"
