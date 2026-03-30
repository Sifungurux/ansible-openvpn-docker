# ──────────────────────────────────────────────────────────────────────────────
# Makefile – ansible-openvpn-docker
#
# Targets
#   make test-start    Start the Lima test VM
#   make test-run      Run the Ansible role against the Lima VM
#   make test-stop     Stop and delete the Lima test VM
#   make test          Full cycle: start → run → stop
#   make docker-build  Build the Docker image (standalone mode)
# ──────────────────────────────────────────────────────────────────────────────

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

LIMA_VM      := openvpn-test
LIMA_CONFIG  := tests/lima/$(LIMA_VM).yaml
PLAYBOOK     := tests/main.yml

GREEN := \033[0;32m
CYAN  := \033[0;36m
NC    := \033[0m

.PHONY: help test-start test-run test-stop test docker-build

help: ## Show available targets
	@echo ""
	@echo "  ansible-openvpn-docker – local test targets"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-16s$(NC) %s\n", $$1, $$2}'
	@echo ""

test-start: ## Start the Lima test VM (Debian 12)
	@echo -e "$(GREEN)[test]$(NC) Starting Lima VM '$(LIMA_VM)'..."
	@limactl start $(LIMA_CONFIG)
	@echo -e "$(GREEN)[test]$(NC) VM ready."

test-run: ## Run the Ansible role against the Lima VM
	@echo -e "$(GREEN)[test]$(NC) Resolving Lima SSH config..."
	@limactl show-ssh $(LIMA_VM) --format config > /tmp/lima-$(LIMA_VM)-ssh.cfg
	@LIMA_PORT=$$(grep -m1 'Port' /tmp/lima-$(LIMA_VM)-ssh.cfg | awk '{print $$2}') && \
	 LIMA_USER=$$(grep -m1 'User' /tmp/lima-$(LIMA_VM)-ssh.cfg | awk '{print $$2}') && \
	 echo -e "$(GREEN)[test]$(NC) Running playbook (host=127.0.0.1:$$LIMA_PORT user=$$LIMA_USER)..." && \
	 ansible-playbook $(PLAYBOOK) \
	   -i "127.0.0.1," \
	   -e "ansible_port=$$LIMA_PORT" \
	   -e "ansible_user=$$LIMA_USER" \
	   -e "ansible_ssh_private_key_file=$$HOME/.lima/_config/user" \
	   --skip-tags "addclient,docker"

test-stop: ## Stop and delete the Lima test VM
	@echo -e "$(GREEN)[test]$(NC) Stopping Lima VM '$(LIMA_VM)'..."
	@limactl stop $(LIMA_VM) 2>/dev/null || true
	@limactl delete $(LIMA_VM) 2>/dev/null || true
	@rm -f /tmp/lima-$(LIMA_VM)-ssh.cfg
	@echo -e "$(GREEN)[test]$(NC) VM removed."

test: test-start test-run test-stop ## Full test cycle: start → run → stop

docker-build: ## Build the Docker image
	@docker build -t openvpn -f tests/Dockerfile .
