
SCRIPT_NAME = safe_rm.sh
INSTALL_DIR = $(HOME)/.local/bin
LOG_FILE = $(HOME)/.safe_rm.log

RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[0;33m
NC = \033[0m

VERSION := $(shell grep '^VERSION=' $(SCRIPT_NAME) | cut -d'"' -f2)

# Detect OS for sed compatibility
UNAME := $(shell uname)
ifeq ($(UNAME), Darwin)
    SED_INPLACE = sed -i ''
else
    SED_INPLACE = sed -i
endif

# Default target
.PHONY: all
all: help

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

.PHONY: check-path
check-path:
	@if echo "$$PATH" | grep -q "$(HOME)/.local/bin"; then \
		echo "${GREEN}✓ $(HOME)/.local/bin is in your PATH${NC}"; \
	else \
		echo "${YELLOW}⚠ Warning: $(HOME)/.local/bin is not in your PATH${NC}"; \
		echo "Add the following to your shell configuration file:"; \
		echo "export PATH=\"\$$PATH:$(HOME)/.local/bin\""; \
	fi

.PHONY: i
i: install

.PHONY: install
install: setup check-path
	@echo "Installing $(SCRIPT_NAME) to $(INSTALL_DIR)..."
	@if [ ! -f "$(SCRIPT_NAME)" ]; then \
		echo "${RED}Error: $(SCRIPT_NAME) not found in current directory${NC}"; \
		exit 1; \
	fi
	@mkdir -p $(INSTALL_DIR)
	@if [ -f "$(INSTALL_DIR)/$(SCRIPT_NAME)" ]; then \
		echo "${YELLOW}Script already installed. Updating...${NC}"; \
	fi
	@cp $(SCRIPT_NAME) $(INSTALL_DIR)/
	@chmod +x $(INSTALL_DIR)/$(SCRIPT_NAME)
	@echo "Creating aliases..."
	@if [ -f "$(HOME)/.bashrc" ]; then \
		cp "$(HOME)/.bashrc" "$(HOME)/.bashrc.bak.$(shell date +%Y%m%d%H%M%S)" 2>/dev/null || true; \
		if grep -q "alias rm=.*$(SCRIPT_NAME)" "$(HOME)/.bashrc" 2>/dev/null; then \
			echo "${YELLOW}Alias already exists in ~/.bashrc${NC}"; \
		else \
			echo "" >> "$(HOME)/.bashrc"; \
			echo "# Added by safe_rm installer $(shell date)" >> "$(HOME)/.bashrc"; \
			echo "alias rm='$(INSTALL_DIR)/$(SCRIPT_NAME)'" >> "$(HOME)/.bashrc"; \
			echo "${GREEN}Added alias to ~/.bashrc${NC}"; \
		fi; \
	else \
		echo "${YELLOW}~/.bashrc not found, creating it...${NC}"; \
		echo "# Added by safe_rm installer $(shell date)" > "$(HOME)/.bashrc"; \
		echo "alias rm='$(INSTALL_DIR)/$(SCRIPT_NAME)'" >> "$(HOME)/.bashrc"; \
		echo "${GREEN}Created ~/.bashrc with alias${NC}"; \
	fi
	@if [ -f "$(HOME)/.zshrc" ]; then \
		cp "$(HOME)/.zshrc" "$(HOME)/.zshrc.bak.$(shell date +%Y%m%d%H%M%S)" 2>/dev/null || true; \
		if grep -q "alias rm=.*$(SCRIPT_NAME)" "$(HOME)/.zshrc" 2>/dev/null; then \
			echo "${YELLOW}Alias already exists in ~/.zshrc${NC}"; \
		else \
			echo "" >> "$(HOME)/.zshrc"; \
			echo "# Added by safe_rm installer $(shell date)" >> "$(HOME)/.zshrc"; \
			echo "alias rm='$(INSTALL_DIR)/$(SCRIPT_NAME)'" >> "$(HOME)/.zshrc"; \
			echo "${GREEN}Added alias to ~/.zshrc${NC}"; \
		fi; \
	else \
		echo "${YELLOW}~/.zshrc not found, skipping...${NC}"; \
	fi
	@echo "${GREEN}Installation complete!${NC}"
	@echo "${YELLOW}To use safe_rm immediately, run:${NC}"
	@echo "  source ~/.bashrc  # if using bash"
	@echo "  source ~/.zshrc   # if using zsh"
	@echo "${YELLOW}Or restart your terminal.${NC}"

.PHONY: uninstall
uninstall:
	@echo "Removing $(SCRIPT_NAME) from $(INSTALL_DIR)..."
	@if [ -f "$(INSTALL_DIR)/$(SCRIPT_NAME)" ]; then \
		rm -f $(INSTALL_DIR)/$(SCRIPT_NAME); \
		echo "${GREEN}Script removed.${NC}"; \
	else \
		echo "${YELLOW}Script not found in $(INSTALL_DIR) - nothing to remove.${NC}"; \
	fi
	@if [ -f "$(HOME)/.bashrc" ]; then \
		if grep -q "alias rm=.*$(SCRIPT_NAME)" "$(HOME)/.bashrc" 2>/dev/null; then \
			$(SED_INPLACE) -e '/# Added by safe_rm installer/d' -e '/alias rm=.*$(SCRIPT_NAME)/d' "$(HOME)/.bashrc"; \
			echo "${GREEN}Alias removed from ~/.bashrc${NC}"; \
		else \
			echo "${YELLOW}No alias found in ~/.bashrc - nothing to remove.${NC}"; \
		fi; \
	fi
	@if [ -f "$(HOME)/.zshrc" ]; then \
		if grep -q "alias rm=.*$(SCRIPT_NAME)" "$(HOME)/.zshrc" 2>/dev/null; then \
			$(SED_INPLACE) -e '/# Added by safe_rm installer/d' -e '/alias rm=.*$(SCRIPT_NAME)/d' "$(HOME)/.zshrc"; \
			echo "${GREEN}Alias removed from ~/.zshrc${NC}"; \
		else \
			echo "${YELLOW}No alias found in ~/.zshrc - nothing to remove.${NC}"; \
		fi; \
	fi
	@echo "Removing log file $(LOG_FILE)..."
	@if [ -f "$(LOG_FILE)" ]; then \
		rm -f $(LOG_FILE); \
		echo "${GREEN}Log file removed.${NC}"; \
	else \
		echo "${YELLOW}Log file not found - nothing to remove.${NC}"; \
	fi
	@echo "${GREEN}Uninstallation complete. Please restart your shell or source your shell config file.${NC}"

.PHONY: test
test: setup
	@echo "Running tests..."
	@if [ ! -f tests/test.sh ]; then \
		echo "${RED}Error: test.sh not found in tests directory${NC}"; \
		exit 1; \
	fi
	@mkdir -p tests
	@bash tests/test.sh > tests/test_results.log 2>&1 || true
	@tail -n 2 tests/test_results.log
	@if grep -q "All tests passed successfully!" tests/test_results.log; then \
		$(MAKE) clean; \
		exit 0; \
	elif grep -q "[0-9]\\+ tests failed" tests/test_results.log; then \
		$(MAKE) clean; \
		exit 0; \
	else \
		echo "${RED}✗ Unexpected test output!${NC}"; \
		$(MAKE) clean; \
		exit 0; \
	fi

.PHONY: clean
clean:
	@rm -rf tests/safe_rm_test
	@find . -name "*.bak" -delete
	@find . -name "*~" -delete
	@echo "${GREEN}Clean up complete.${NC}"

.PHONY: setup
setup:
	@echo "Setting up directories and log file..."
	@mkdir -p $(INSTALL_DIR)
	@touch $(LOG_FILE)
	@chmod 644 $(LOG_FILE)
	@echo "${GREEN}Setup complete. Log file at: $(LOG_FILE)${NC}"

.PHONY: verify
verify:
	@echo "Verifying installation..."
	@if [ -x "$(INSTALL_DIR)/$(SCRIPT_NAME)" ]; then \
		echo "${GREEN}✓ Script is installed and executable${NC}"; \
	else \
		echo "${RED}✗ Script is not properly installed (in $(INSTALL_DIR))${NC}"; \
	fi
	@if [ -f "$(HOME)/.bashrc" ]; then \
		if grep -q "alias rm=.*$(SCRIPT_NAME)" "$(HOME)/.bashrc" 2>/dev/null; then \
			echo "${GREEN}✓ Alias is configured in ~/.bashrc${NC}"; \
		else \
			echo "${RED}✗ Alias is not configured in ~/.bashrc${NC}"; \
		fi; \
	else \
		echo "${YELLOW}⚠ ~/.bashrc not found${NC}"; \
	fi
	@if [ -f "$(HOME)/.zshrc" ]; then \
		if grep -q "alias rm=.*$(SCRIPT_NAME)" "$(HOME)/.zshrc" 2>/dev/null; then \
			echo "${GREEN}✓ Alias is configured in ~/.zshrc${NC}"; \
		else \
			echo "${RED}✗ Alias is not configured in ~/.zshrc${NC}"; \
		fi; \
	else \
		echo "${YELLOW}⚠ ~/.zshrc not found${NC}"; \
	fi
	@if [ -f "$(LOG_FILE)" ]; then \
		echo "${GREEN}✓ Log file exists: $(LOG_FILE)${NC}"; \
	else \
		echo "${RED}✗ Log file does not exist${NC}"; \
	fi
	@$(MAKE) check-path

.PHONY: version
version:
	@echo "Safe_rm version $(VERSION)"

.PHONY: docs
docs:
	@echo "Generating documentation..."
	@echo "${YELLOW}Documentation generation will be implemented in a future version.${NC}"

# Update to latest version (if using git)
.PHONY: update
update:
	@echo "Checking for updates..."
	@if command -v git > /dev/null && [ -d .git ]; then \
		git fetch > /dev/null 2>&1 || { echo "${RED}Failed to fetch updates.${NC}"; exit 1; }; \
		if [ $$(git rev-list HEAD...origin/main --count 2>/dev/null) -gt 0 ]; then \
			echo "${YELLOW}Updates available. Updating...${NC}"; \
			git pull origin main > /dev/null 2>&1 || { echo "${RED}Failed to pull updates.${NC}"; exit 1; }; \
			echo "${GREEN}Update complete. Run 'make install' to apply changes.${NC}"; \
		else \
			echo "${GREEN}Already up to date.${NC}"; \
		fi; \
	else \
		echo "${RED}Not a git repository or git not installed. Manual update required.${NC}"; \
	fi
