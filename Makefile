# ──────────────────────────────────────────────────────────────────────────────
# Makefile – ansible-openvpn-docker
#
# Targets
#   make test-start      Start the server Lima VM
#   make test-run        Run the Ansible role against the server VM
#   make test-stop       Stop and delete the server Lima VM
#   make client-start    Start the client Lima VM
#   make client-run      Generate client cert on server, push to client VM
#   make client-stop     Stop and delete the client Lima VM
#   make test            Server-only test cycle: start → run → stop
#   make test-e2e        Full end-to-end cycle: server + client + tunnel assert
#   make docker-build    Build the Docker image (standalone mode)
# ──────────────────────────────────────────────────────────────────────────────

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

LIMA_VM        := openvpn-test
LIMA_CONFIG    := tests/lima/$(LIMA_VM).yaml
PLAYBOOK       := tests/main.yml
SSH_CFG        := /tmp/lima-$(LIMA_VM)-ssh.cfg

LIMA_CLIENT    := openvpn-client
CLIENT_CONFIG  := tests/lima/$(LIMA_CLIENT).yaml
CLIENT_PLAYBOOK := tests/client.yml
CLIENT_SSH_CFG := /tmp/lima-$(LIMA_CLIENT)-ssh.cfg
CLIENT_INV     := /tmp/lima-client-inventory.ini

GREEN := \033[0;32m
CYAN  := \033[0;36m
NC    := \033[0m

.PHONY: help test-start test-run test-stop client-start client-run client-stop test test-e2e docker-build

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

test-run: ## Run the Ansible role against the Lima VM over SSH
	@echo -e "$(GREEN)[test]$(NC) Generating SSH config for Lima VM '$(LIMA_VM)'..."
	@limactl show-ssh $(LIMA_VM) --format config > $(SSH_CFG)
	@echo -e "$(GREEN)[test]$(NC) Running playbook against Lima VM '$(LIMA_VM)' over SSH..."
	@ansible-playbook $(PLAYBOOK) \
	  -i "lima-$(LIMA_VM)," \
	  -e "ansible_ssh_extra_args='-F $(SSH_CFG)'" \
	  --skip-tags "addclient,docker"

test-stop: ## Stop and delete the server Lima VM
	@echo -e "$(GREEN)[test]$(NC) Stopping Lima VM '$(LIMA_VM)'..."
	@limactl stop $(LIMA_VM) 2>/dev/null || true
	@limactl delete $(LIMA_VM) 2>/dev/null || true
	@rm -f $(SSH_CFG)
	@echo -e "$(GREEN)[test]$(NC) VM removed."

client-start: ## Start the client Lima VM (Debian 12)
	@echo -e "$(GREEN)[client]$(NC) Starting Lima VM '$(LIMA_CLIENT)'..."
	@limactl start $(CLIENT_CONFIG)
	@echo -e "$(GREEN)[client]$(NC) VM ready."

client-run: ## Generate client cert on server, distribute certs and config to client VM
	@echo -e "$(GREEN)[client]$(NC) Generating SSH configs..."
	@limactl show-ssh $(LIMA_VM) --format config > $(SSH_CFG)
	@limactl show-ssh $(LIMA_CLIENT) --format config >> $(SSH_CFG)
	@printf '[vpn_server]\nlima-$(LIMA_VM)\n\n[vpn_client]\nlima-$(LIMA_CLIENT)\n' > $(CLIENT_INV)
	@echo -e "$(GREEN)[client]$(NC) Running client playbook..."
	@ansible-playbook $(CLIENT_PLAYBOOK) \
	  -i $(CLIENT_INV) \
	  -e "ansible_ssh_extra_args='-F $(SSH_CFG)'"

client-stop: ## Stop and delete the client Lima VM
	@echo -e "$(GREEN)[client]$(NC) Stopping Lima VM '$(LIMA_CLIENT)'..."
	@limactl stop $(LIMA_CLIENT) 2>/dev/null || true
	@limactl delete $(LIMA_CLIENT) 2>/dev/null || true
	@rm -f $(CLIENT_SSH_CFG) $(CLIENT_INV) /tmp/openvpn-testclient
	@echo -e "$(GREEN)[client]$(NC) VM removed."

test: test-start test-run test-stop ## Server-only test cycle: start → run → stop

test-e2e: test-start test-run client-start client-run client-stop test-stop ## Full end-to-end cycle: server + client + tunnel assertion

docker-build: ## Build the Docker image
	@docker build -t openvpn -f tests/Dockerfile .
