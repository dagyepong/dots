# Root Makefile for HypeShell
# Orchestrates building, installation, and systemd management

# Build configuration
BINARY_NAME=hype
CORE_DIR=core
BUILD_DIR=$(CORE_DIR)/bin
PREFIX ?= /usr/local
INSTALL_DIR=$(PREFIX)/bin
DATA_DIR=$(PREFIX)/share
ICON_DIR=$(DATA_DIR)/icons/hicolor/scalable/apps

USER_HOME := $(if $(SUDO_USER),$(shell getent passwd $(SUDO_USER) | cut -d: -f6),$(HOME))
USER_GROUP := $(if $(SUDO_USER),$(shell id -gn $(SUDO_USER) 2>/dev/null),)
SYSTEMD_USER_DIR=$(USER_HOME)/.config/systemd/user

SHELL_DIR=quickshell
SHELL_INSTALL_DIR=$(DATA_DIR)/quickshell/hype
ASSETS_DIR=assets
APPLICATIONS_DIR=$(DATA_DIR)/applications

.PHONY: all build clean lint-qml install install-bin install-shell install-completions install-systemd install-icon install-desktop uninstall uninstall-bin uninstall-shell uninstall-completions uninstall-systemd uninstall-icon uninstall-desktop help

all: build

build:
	@if ! command -v go >/dev/null 2>&1; then \
		echo ""; \
		echo "=================================================================="; \
		echo "❌ BUILD ERROR: 'go' compiler not found in PATH!"; \
		echo "Please install Go (1.22+) or ensure it is in your system PATH."; \
		echo "Current PATH: $$PATH"; \
		echo "=================================================================="; \
		echo ""; \
		exit 1; \
	fi
	@echo "Building $(BINARY_NAME)..."
	@$(MAKE) -C $(CORE_DIR) build
	@echo "Build complete"

clean:
	@echo "Cleaning build artifacts..."
	@$(MAKE) -C $(CORE_DIR) clean
	@echo "Clean complete"

lint-qml:
	@./quickshell/scripts/qmllint-entrypoints.sh

# Installation targets
install-bin: build
	@echo "Installing $(BINARY_NAME) to $(INSTALL_DIR)..."
	@install -D -m 755 $(BUILD_DIR)/$(BINARY_NAME) $(INSTALL_DIR)/$(BINARY_NAME)
	@rm -f $(INSTALL_DIR)/dms
	@echo "Binary installed"

install-shell:
	@echo "Installing shell files to $(SHELL_INSTALL_DIR)..."
	@mkdir -p $(SHELL_INSTALL_DIR)
	@cp -r $(SHELL_DIR)/* $(SHELL_INSTALL_DIR)/
	@rm -rf $(SHELL_INSTALL_DIR)/.git* $(SHELL_INSTALL_DIR)/.github
	@echo "Shell files installed"

install-completions: build
	@echo "Installing shell completions..."
	@mkdir -p $(DATA_DIR)/bash-completion/completions
	@mkdir -p $(DATA_DIR)/zsh/site-functions
	@mkdir -p $(DATA_DIR)/fish/vendor_completions.d
	@$(BUILD_DIR)/$(BINARY_NAME) completion bash > $(DATA_DIR)/bash-completion/completions/hype 2>/dev/null || true
	@$(BUILD_DIR)/$(BINARY_NAME) completion zsh > $(DATA_DIR)/zsh/site-functions/_hype 2>/dev/null || true
	@$(BUILD_DIR)/$(BINARY_NAME) completion fish > $(DATA_DIR)/fish/vendor_completions.d/hype.fish 2>/dev/null || true
	@rm -f $(DATA_DIR)/bash-completion/completions/dms $(DATA_DIR)/zsh/site-functions/_dms $(DATA_DIR)/fish/vendor_completions.d/dms.fish
	@echo "Shell completions installed"

install-systemd:
	@echo "Installing systemd user service..."
	@mkdir -p $(SYSTEMD_USER_DIR)
	@if [ -n "$(SUDO_USER)" ]; then chown -R $(SUDO_USER):"$(USER_GROUP)" $(SYSTEMD_USER_DIR); fi
	@sed 's|/usr/bin/hype|$(INSTALL_DIR)/hype|g' $(ASSETS_DIR)/systemd/hype.service > $(SYSTEMD_USER_DIR)/hype.service
	@rm -f $(SYSTEMD_USER_DIR)/dms.service
	@chmod 644 $(SYSTEMD_USER_DIR)/hype.service
	@if [ -n "$(SUDO_USER)" ]; then chown $(SUDO_USER):"$(USER_GROUP)" $(SYSTEMD_USER_DIR)/hype.service; fi
	@echo "Systemd service installed to $(SYSTEMD_USER_DIR)/hype.service"

install-icon:
	@echo "Installing icon..."
	@install -D -m 644 $(ASSETS_DIR)/hypeshell-logo.svg $(ICON_DIR)/hypeshell-logo.svg
	@install -D -m 644 $(ASSETS_DIR)/hypeshell-logo.svg $(ICON_DIR)/danklogo.svg
	@gtk-update-icon-cache -q $(DATA_DIR)/icons/hicolor 2>/dev/null || true
	@echo "Icon installed"

install-desktop:
	@echo "Installing desktop entry..."
	@install -D -m 644 $(ASSETS_DIR)/hype-open.desktop $(APPLICATIONS_DIR)/hype-open.desktop
	@rm -f $(APPLICATIONS_DIR)/dms-open.desktop
	@update-desktop-database -q $(APPLICATIONS_DIR) 2>/dev/null || true
	@echo "Desktop entry installed"

install: build install-bin install-shell install-completions install-systemd install-icon install-desktop
	@echo ""
	@echo "Installation complete!"
	@echo ""
	@echo "=== Cheers, the HypeShell Team! ==="

# Uninstallation targets
uninstall-bin:
	@echo "Removing $(BINARY_NAME) from $(INSTALL_DIR)..."
	@rm -f $(INSTALL_DIR)/$(BINARY_NAME)
	@rm -f $(INSTALL_DIR)/dms
	@echo "Binary removed"

uninstall-shell:
	@echo "Removing shell files from $(SHELL_INSTALL_DIR)..."
	@rm -rf $(SHELL_INSTALL_DIR)
	@echo "Shell files removed"

uninstall-completions:
	@echo "Removing shell completions..."
	@rm -f $(DATA_DIR)/bash-completion/completions/hype
	@rm -f $(DATA_DIR)/bash-completion/completions/dms
	@rm -f $(DATA_DIR)/zsh/site-functions/_hype
	@rm -f $(DATA_DIR)/zsh/site-functions/_dms
	@rm -f $(DATA_DIR)/fish/vendor_completions.d/hype.fish
	@rm -f $(DATA_DIR)/fish/vendor_completions.d/dms.fish
	@echo "Shell completions removed"

uninstall-systemd:
	@echo "Removing systemd user service..."
	@rm -f $(SYSTEMD_USER_DIR)/hype.service
	@rm -f $(SYSTEMD_USER_DIR)/dms.service
	@echo "Systemd service removed"
	@echo "Note: Stop/disable service manually if running: systemctl --user stop hype"

uninstall-icon:
	@echo "Removing icon..."
	@rm -f $(ICON_DIR)/hypeshell-logo.svg
	@rm -f $(ICON_DIR)/danklogo.svg
	@gtk-update-icon-cache -q $(DATA_DIR)/icons/hicolor 2>/dev/null || true
	@echo "Icon removed"

uninstall-desktop:
	@echo "Removing desktop entry..."
	@rm -f $(APPLICATIONS_DIR)/hype-open.desktop
	@rm -f $(APPLICATIONS_DIR)/dms-open.desktop
	@update-desktop-database -q $(APPLICATIONS_DIR) 2>/dev/null || true
	@echo "Desktop entry removed"

uninstall: uninstall-systemd uninstall-desktop uninstall-icon uninstall-completions uninstall-shell uninstall-bin
	@echo ""
	@echo "Uninstallation complete!"

# Target assist
help:
	@echo "Available targets:"
	@echo ""
	@echo "Build:"
	@echo "  all (default)        - Build the HypeShell binary"
	@echo "  build                - Same as 'all'"
	@echo "  clean                - Clean build artifacts"
	@echo "  lint-qml             - Run qmllint on shell entrypoints using the Quickshell tooling VFS"
	@echo ""
	@echo "Install:"
	@echo "  install              - Build and install everything (requires sudo)"
	@echo "  install-bin          - Install only the binary"
	@echo "  install-shell        - Install only shell files"
	@echo "  install-completions  - Install only shell completions"
	@echo "  install-systemd      - Install only systemd service"
	@echo "  install-icon         - Install only icon"
	@echo "  install-desktop      - Install only desktop entry"
	@echo ""
	@echo "Uninstall:"
	@echo "  uninstall            - Remove everything (requires sudo)"
	@echo "  uninstall-bin        - Remove only the binary"
	@echo "  uninstall-shell      - Remove only shell files"
	@echo "  uninstall-completions - Remove only shell completions"
	@echo "  uninstall-systemd    - Remove only systemd service"
	@echo "  uninstall-icon       - Remove only icon"
	@echo "  uninstall-desktop    - Remove only desktop entry"
	@echo ""
	@echo "Usage:"
	@echo "  sudo make install               - Build and install HypeShell"
	@echo "  sudo make uninstall             - Remove HypeShell"
	@echo "  systemctl --user enable --now hype  - Enable and start service"
