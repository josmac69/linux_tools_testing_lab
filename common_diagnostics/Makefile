# Makefile for the Common Diagnostics Lab
#
# Unlike the other labs, these tools run directly on the HOST (no Docker),
# because their whole purpose is to inspect the real machine.

.PHONY: healthcheck healthcheck-root save help

help:
	@echo "Common Diagnostics Lab — always-available Linux tests"
	@echo ""
	@echo "  make healthcheck        Read-only snapshot: performance/network/firewall/disk"
	@echo "  make healthcheck-root   Same, via sudo (adds full firewall ruleset)"
	@echo "  make save               Write a timestamped snapshot to /tmp"
	@echo ""
	@echo "See README.md and 0{1..4}_*.md for how to interpret the output."

healthcheck:
	@./scripts/quick_healthcheck.sh

healthcheck-root:
	@sudo ./scripts/quick_healthcheck.sh

save:
	@out="/tmp/healthcheck_$$(date +%Y%m%d_%H%M%S).txt"; \
	./scripts/quick_healthcheck.sh > "$$out" 2>&1; \
	echo "Snapshot saved to $$out"
