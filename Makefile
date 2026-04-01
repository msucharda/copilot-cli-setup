# ──────────────────────────────────────────────────────────────
# Copilot CLI Test VM — Developer Makefile
# Usage: make deploy  |  make destroy  |  make ssh
# ──────────────────────────────────────────────────────────────

ENV          ?= dev
TEMPLATE     := infra/main.bicep
PARAMS       := infra/main.$(ENV).bicepparam
LOCATION     := swedencentral
RG_NAME      := rg-copilot-test-$(ENV)
DEPLOY_NAME  := deploy-copilot-test-$(ENV)-$(shell date +%Y%m%d%H%M%S)
ADMIN_USER   ?= copilotadmin

.PHONY: help lint build validate what-if deploy destroy ip ssh deploy-script test-remote clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ── Bicep checks ─────────────────────────────────────────────

lint: ## Lint Bicep files
	az bicep lint --file $(TEMPLATE)

build: ## Build Bicep to ARM (syntax check)
	az bicep build --file $(TEMPLATE) --stdout > /dev/null
	@echo "✅ Build successful"

validate: ## Validate deployment against Azure
	@az group show --name $(RG_NAME) > /dev/null 2>&1 || \
		az group create --name $(RG_NAME) --location $(LOCATION) --tags environment=$(ENV) managed-by=bicep > /dev/null
	az deployment group validate \
		--name $(DEPLOY_NAME) \
		--resource-group $(RG_NAME) \
		--template-file $(TEMPLATE) \
		--parameters $(PARAMS)
	@echo "✅ Validation passed"

what-if: ## Preview changes (what-if)
	@az group show --name $(RG_NAME) > /dev/null 2>&1 || \
		az group create --name $(RG_NAME) --location $(LOCATION) --tags environment=$(ENV) managed-by=bicep > /dev/null
	az deployment group what-if \
		--name $(DEPLOY_NAME) \
		--resource-group $(RG_NAME) \
		--template-file $(TEMPLATE) \
		--parameters $(PARAMS)

# ── Deploy / Destroy ─────────────────────────────────────────

accept-terms: ## Accept Windows 11 marketplace terms (one-time)
	az vm image terms accept \
		--publisher MicrosoftWindowsDesktop \
		--offer windows-11 \
		--plan win11-24h2-ent

deploy: ## Deploy the test VM to Azure
	@az group show --name $(RG_NAME) > /dev/null 2>&1 || \
		az group create --name $(RG_NAME) --location $(LOCATION) --tags environment=$(ENV) managed-by=bicep
	az deployment group create \
		--name $(DEPLOY_NAME) \
		--resource-group $(RG_NAME) \
		--template-file $(TEMPLATE) \
		--parameters $(PARAMS)
	@echo "✅ Deployment complete"
	@echo "Run 'make ip' to get the VM's public IP address"

destroy: ## Delete the resource group and ALL resources
	az group delete --name $(RG_NAME) --yes --no-wait
	@echo "🗑️  Deleting $(RG_NAME) (async)"

# ── SSH access ───────────────────────────────────────────────

ip: ## Get the VM's public IP address
	@az vm show -d --name vm-copilot-$(ENV) --resource-group $(RG_NAME) \
		--query publicIps -o tsv

ssh: ## SSH into the test VM
	@IP=$$(az vm show -d --name vm-copilot-$(ENV) --resource-group $(RG_NAME) \
		--query publicIps -o tsv) && \
	echo "Connecting to $$IP as $(ADMIN_USER)..." && \
	ssh -o StrictHostKeyChecking=accept-new $(ADMIN_USER)@$$IP

# ── Script deployment & testing ──────────────────────────────

deploy-script: ## Copy and run bootstrap-copilot.ps1 on the VM
	@IP=$$(az vm show -d --name vm-copilot-$(ENV) --resource-group $(RG_NAME) \
		--query publicIps -o tsv) && \
	echo ">> Copying bootstrap-copilot.ps1 to $$IP..." && \
	scp -o StrictHostKeyChecking=accept-new bootstrap-copilot.ps1 $(ADMIN_USER)@$$IP:C:/Users/$(ADMIN_USER)/bootstrap-copilot.ps1 && \
	echo ">> Running bootstrap script..." && \
	ssh -o StrictHostKeyChecking=accept-new $(ADMIN_USER)@$$IP \
		"powershell -ExecutionPolicy Bypass -File C:\Users\$(ADMIN_USER)\bootstrap-copilot.ps1"

test-remote: ## Run bootstrap and verify all tools are installed
	@IP=$$(az vm show -d --name vm-copilot-$(ENV) --resource-group $(RG_NAME) \
		--query publicIps -o tsv) && \
	echo ">> Copying bootstrap-copilot.ps1 to $$IP..." && \
	scp -o StrictHostKeyChecking=accept-new bootstrap-copilot.ps1 $(ADMIN_USER)@$$IP:C:/Users/$(ADMIN_USER)/bootstrap-copilot.ps1 && \
	echo ">> Running bootstrap script..." && \
	ssh -o StrictHostKeyChecking=accept-new $(ADMIN_USER)@$$IP \
		"powershell -ExecutionPolicy Bypass -File C:\Users\$(ADMIN_USER)\bootstrap-copilot.ps1" && \
	echo "" && \
	echo ">> Verifying installations..." && \
	ssh -o StrictHostKeyChecking=accept-new $(ADMIN_USER)@$$IP \
		"powershell -Command \" \
			Write-Host '=== Tool Verification ===' ; \
			\$$tools = @( \
				@{Cmd='pwsh'; Arg='--version'}, \
				@{Cmd='gh'; Arg='--version'}, \
				@{Cmd='az'; Arg='version'}, \
				@{Cmd='node'; Arg='--version'}, \
				@{Cmd='npm'; Arg='--version'}, \
				@{Cmd='copilot'; Arg='--version'} \
			) ; \
			\$$failed = 0 ; \
			foreach (\$$t in \$$tools) { \
				if (Get-Command \$$t.Cmd -ErrorAction SilentlyContinue) { \
					\$$v = & \$$t.Cmd \$$t.Arg 2>&1 | Select-Object -First 1 ; \
					Write-Host \\\"  [OK] \$$(\$$t.Cmd): \$$v\\\" \
				} else { \
					Write-Host \\\"  [FAIL] \$$(\$$t.Cmd) not found\\\" ; \
					\$$failed++ \
				} \
			} ; \
			if (\$$failed -gt 0) { exit 1 } else { Write-Host '=== All tools verified ===' } \
		\""

clean: ## Remove generated ARM JSON files
	find infra/ -name '*.json' ! -name 'bicepconfig.json' -delete
	@echo "✅ Cleaned"
