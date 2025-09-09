SHELL=/usr/bin/env
.SHELLFLAGS=bash -euo pipefail -c
GCS_PREFIX=gs://csm-release-public/hotfix
CSM_RELEASE=1.6

.PHONY: list
list: pre-flight-checks
	@$(MAKE) -s dist/build.txt

dist/build.txt:
	@mkdir -p dist
	@rm -f dist/build.txt
	@touch dist/build.txt
	@while read VERSION_SH; do \
		HOTFIX_NAME=$$(eval "$${VERSION_SH}"); \
 		GCS_FILE="$(GCS_PREFIX)/csm-$(CSM_RELEASE)/$${HOTFIX_NAME}.tar.gz"; \
		echo -ne "Checking existence of csm-$(CSM_RELEASE)/$${HOTFIX_NAME} ... "; \
		if gsutil -q stat "$${GCS_FILE}"; then \
			echo "ok"; \
		else \
			echo "not found"; \
			echo "$${VERSION_SH}" >> dist/build.txt; \
		fi; \
	done < <(find hotfix/ -maxdepth 3 -mindepth 3 -wholename '*/lib/version.sh')

.PHONY: build
build: dist/build.txt
	@echo "Hotfixes to build:"
	@cat dist/build.txt
	@while read VERSION_SH; do \
		HOTFIX_DIR="$${VERSION_SH%%/lib/version.sh}"; \
		echo "Building $${HOTFIX_DIR}"; \
		./release.sh "$${HOTFIX_DIR}"; \
	done < dist/build.txt

.PHONY: upload
upload: build
	@echo "Hotfixes to upload:"
	@cat dist/build.txt
	@rm -f dist/slack.txt
	@touch dist/slack.txt
	@while read VERSION_SH; do \
		HOTFIX_NAME=$$(eval "$${VERSION_SH}"); \
		GCS_URL="$(GCS_PREFIX)/csm-$(CSM_RELEASE)/$${HOTFIX_NAME}.tar.gz"; \
		cd dist; \
		sha256sum $${HOTFIX_NAME}.tar.gz > $${HOTFIX_NAME}.tar.gz.sha256.txt; \
		cd ..; \
		echo -ne "Uploading csm-$(CSM_RELEASE)/$${HOTFIX_NAME} ... "; \
		echo gsutil cp -n "dist/$${HOTFIX_NAME}.tar.gz" "$${GCS_URL}"; \
		echo gsutil cp -n "dist/$${HOTFIX_NAME}.tar.gz.sha256.txt" "$${GCS_URL}.sha256.txt"; \
		echo "Hotfix $${HOTFIX_NAME} uploaded to $${GCS_URL}" >> dist/slack.txt; \
	done < dist/build.txt

.PHONY: clean
clean:
	@echo -ne "Cleaning up dist/ ... "
	@rm -rf dist/
	@echo "ok"

.PHONY: pre-flight-checks
pre-flight-checks:
	@echo -ne "Checking for configured access to $(GCS_PREFIX) ... "
	@gsutil -q ls $(GCS_PREFIX)/ > /dev/null
	@echo ok
