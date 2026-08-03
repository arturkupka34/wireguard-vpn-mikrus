SHELL := /usr/bin/env bash

SCRIPTS := \
	install.sh \
	preflight.sh \
	configure-repository.sh \
	src/mikrus-wg \
	tests/smoke.sh \
	tests/firewall-mock.sh \
	tests/config-mock.sh \
	tests/install-mock.sh \
	tests/bootstrap-mock.sh \
	tests/update-mock.sh

.PHONY: test ci syntax shellcheck workflow checksum repository-audit package

test: syntax workflow checksum repository-audit
	@bash tests/smoke.sh
	@bash tests/firewall-mock.sh
	@bash tests/config-mock.sh
	@bash tests/install-mock.sh
	@bash tests/bootstrap-mock.sh
	@bash tests/update-mock.sh

ci: syntax workflow checksum repository-audit shellcheck
	@bash tests/smoke.sh
	@bash tests/firewall-mock.sh
	@bash tests/config-mock.sh
	@bash tests/install-mock.sh
	@bash tests/bootstrap-mock.sh
	@bash tests/update-mock.sh

syntax:
	@bash -n $(SCRIPTS)

workflow:
	@python3 tests/validate-workflow.py .github/workflows/ci.yml

checksum:
	@cd src && sha256sum -c mikrus-wg.sha256

repository-audit:
	@python3 tests/repository-audit.py

shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || { echo "Brak ShellCheck." >&2; exit 1; }
	@shellcheck --severity=warning $(SCRIPTS)

package: test
	@tar -czf wireguard-vpn-mikrus-source.tar.gz \
		--exclude=.git \
		--exclude=wireguard-vpn-mikrus-source.tar.gz \
		.
