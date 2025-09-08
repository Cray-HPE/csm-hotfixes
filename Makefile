SHELL=/usr/bin/env
.SHELLFLAGS=bash -euo pipefail -c
GCS_PREFIX=gs://csm-release-public/hotfix

.PHONY: list
list: pre-flight-checks
	@mkdir -p dist
	@rm -f dist/build.txt
	@while read VERSION_SH; do \
		RELEASE=$$(eval "$${VERSION_SH}"); \
		FOLDER="$$(basename "$$(dirname "$${VERSION_SH%/lib/version.sh}")")"; \
 		GCS_FILE="$(GCS_PREFIX)/$${FOLDER}/$${RELEASE}.tar.gz"; \
		echo -ne "Checking existence of $${FOLDER}/$${RELEASE} ... "; \
		if gsutil -q stat "$${GCS_FILE}"; then \
			echo "ok"; \
		else \
			echo "not found"; \
			echo "$${VERSION_SH}" >> dist/build.txt; \
		fi; \
	done < <(find hotfix/ -maxdepth 3 -mindepth 3 -wholename '*/lib/version.sh')

build: list
	@if [ -f dist/build.txt ]; then \
		while read VERSION_SH; do \
			HOTFIX_DIR="$${VERSION_SH%%/lib/version.sh}"; \
			echo "Building $${HOTFIX_DIR}"; \
			./release.sh "$${HOTFIX_DIR}"; \
		done < dist/build.txt; \
	else \
		echo "Nothing to build. Stop."; \
	fi

clean:
	@echo -ne "Cleaning up dist/ ... "
	@rm -rf dist/
	@echo "ok"

pre-flight-checks:
	@echo -ne "Checking for configured access to $(GCS_PREFIX) ... "
	@gsutil -q ls $(GCS_PREFIX)/ > /dev/null
	@echo ok
