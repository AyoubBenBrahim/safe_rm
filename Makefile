# Configuration
SCRIPT_NAME = safe_rm.sh
INSTALL_DIR = $(HOME)/safe_rm
LOG_FILE = $(HOME)/.safe_rm.log

# Define ANSI color codes
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[0;33m
NC = \033[0m

# Version from script
VERSION := $(shell grep '^VERSION=' $(SCRIPT_NAME) | cut -d'"' -f2)

# Default target
.PHONY: all
all: help

# Help message
.PHONY: help
help:
	@echo "Safe RM - Version $(VERSION)"
	@echo "======================="
	@echo "Targets:"
	@echo "  install    - Install the script to $(INSTALL_DIR)"
	@echo "  uninstall  - Remove the script from $(INSTALL_DIR)"
	@echo "  test       - Run all tests"
	@echo "  clean      - Remove temporary files"
	@echo "  setup      - Create necessary directories and log file"
	@echo "  verify     - Check if the script is properly installed"
	@echo "  help       - Show this help message"
	@echo "  version    - Display version information"
	@echo "  docs       - Generate documentation"
	@echo "  update     - Update to the latest version"

# Detect which shell configuration file to use
.PHONY: detect-shell
detect-shell:
	@if [ -n "$$ZSH_VERSION" ]; then \
		echo "$(HOME)/.zshrc"; \
	elif [ -n "$$BASH_VERSION" ]; then \
		echo "$(HOME)/.bashrc"; \
	else \
		echo "$(HOME)/.profile"; \
	fi

# Install with shell detection
.PHONY: install
install: setup
	@echo "Installing $(SCRIPT_NAME) to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	@cp $(SCRIPT_NAME) $(INSTALL_DIR)/
	@chmod +x $(INSTALL_DIR)/$(SCRIPT_NAME)
	@echo "Creating alias..."
	@SHELL_RC=$$($(MAKE) -s detect-shell); \
	if grep -q "alias rm=.*$(SCRIPT_NAME)" $$SHELL_RC 2>/dev/null; then \
		echo "${YELLOW}Alias already exists in $$SHELL_RC${NC}"; \
	else \
		echo "alias rm='$(INSTALL_DIR)/$(SCRIPT_NAME)'" >> $$SHELL_RC; \
		echo "${GREEN}Added alias to $$SHELL_RC${NC}"; \
	fi
	@echo "${GREEN}Installation complete. Please restart your shell or source your shell config file.${NC}"

# Uninstall the script
.PHONY: uninstall
uninstall:
	@echo "Removing $(SCRIPT_NAME) from $(INSTALL_DIR)..."
	@if [ -f "$(INSTALL_DIR)/$(SCRIPT_NAME)" ]; then \
		rm -f $(INSTALL_DIR)/$(SCRIPT_NAME); \
		echo "${GREEN}Script removed.${NC}"; \
	else \
	    echo "${YELLOW}Script not found in $(INSTALL_DIR) - nothing to remove.${NC}"; \
	fi
	@SHELL_RC=$$($(MAKE) -s detect-shell); \
	if grep -q "alias rm=.*$(SCRIPT_NAME)" $$SHELL_RC 2>/dev/null; then \
		sed -i '' -e '/alias rm=.*$(SCRIPT_NAME)/d' $$SHELL_RC; \
		echo "${GREEN}Alias removed from $$SHELL_RC${NC}"; \
	else \
		echo "${YELLOW}No alias found in $$SHELL_RC - nothing to remove.${NC}"; \
	fi
	@echo "${GREEN}Uninstallation complete. Please restart your shell or source your shell config file.${NC}"

# Run tests with dependencies
.PHONY: test
test: setup
	@echo "Running tests..."
	@if [ ! -f tests/test.sh ]; then \
		echo "${RED}Error: test.sh not found in tests directory${NC}"; \
		exit 1; \
	fi
	@bash tests/test.sh > /dev/null 2>&1 || { echo "${RED}Tests failed!${NC}"; exit 1; }

# Clean temporary files
.PHONY: clean
clean:
	@echo "Cleaning up..."
	@rm -rf tests/safe_rm_test
	@rm -f test_results.log
	@find . -name "*.bak" -delete
	@find . -name "*~" -delete
	@echo "${GREEN}Clean up complete.${NC}"

# Setup configuration
.PHONY: setup
setup:
	@echo "Setting up directories and log file..."
	@sudo mkdir -p $(INSTALL_DIR)
	@sudo touch $(LOG_FILE)
	@chmod 644 $(LOG_FILE)
	@echo "${GREEN}Setup complete. Log file at: $(LOG_FILE)${NC}"

# Verify installation
.PHONY: verify
verify:
	@echo "Verifying installation..."
	@if [ -x "$(INSTALL_DIR)/$(SCRIPT_NAME)" ]; then \
	    echo "${GREEN}✓ Script is installed and executable${NC}"; \
	else \
	    echo "${RED}✗ Script is not properly installed${NC}"; \
	fi
	@SHELL_RC=$$($(MAKE) -s detect-shell); \
	if [ -f "$$SHELL_RC" ]; then \
		if grep -q "alias rm=.*$(SCRIPT_NAME)" $$SHELL_RC 2>/dev/null; then \
		    echo "${GREEN}✓ Alias is configured in $$SHELL_RC${NC}"; \
		else \
		    echo "${RED}✗ Alias is not configured${NC}"; \
		fi \
	else \
	    echo "${RED}✗ Shell configuration file not found${NC}"; \
	fi
	@if [ -f "$(LOG_FILE)" ]; then \
	    echo "${GREEN}✓ Log file exists: $(LOG_FILE)${NC}"; \
	else \
	    echo "${RED}✗ Log file does not exist${NC}"; \
	fi

# Display version information
.PHONY: version
version:
	@echo "Safe_rm version $(VERSION)"

# Generate documentation
.PHONY: docs
docs:
	@echo "${YELLOW}update later${NC}"

# Update to latest version (if using git)
.PHONY: update
update:
	@echo "Checking for updates..."
	@if command -v git > /dev/null && [ -d .git ]; then \
		git fetch > /dev/null 2>&1; \
		if [ $$(git rev-list HEAD...origin/main --count) -gt 0 ]; then \
			echo "${YELLOW}Updates available. Updating...${NC}"; \
			git pull origin main > /dev/null 2>&1; \
			echo "${GREEN}Update complete. Run 'make install' to apply changes.${NC}"; \
		else \
			echo "${GREEN}Already up to date.${NC}"; \
		fi; \
	else \
		echo "${RED}Not a git repository or git not installed. Manual update required.${NC}"; \
	fi
