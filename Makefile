# All source code files
ALL_SRC := $(shell find . -name '*.go' -o -name '*.sh' -o -name 'Dockerfile*' -type f | sort)
# Tools module directory
TOOLS_MOD_DIR := internal/tools

# This target cleans the repository
.PHONY: clean
clean:
	@rm -rf release_deps
	@rm -rf supervisor-binaries
	@rm -rf dist

# This target installs tools used in development
.PHONY: install-tools
install-tools:
	cd $(TOOLS_MOD_DIR) && go install github.com/google/addlicense

# This target checks that license copyright header is on every source file
.PHONY: check-license
check-license:
	@ADDLICENSEOUT=`addlicense -check $(ALL_SRC) 2>&1`; \
		if [ "$$ADDLICENSEOUT" ]; then \
			echo "addlicense FAILED => add License errors:\n"; \
			echo "$$ADDLICENSEOUT\n"; \
			echo "Use 'make add-license' to fix this."; \
			exit 1; \
		else \
			echo "Check License finished successfully"; \
		fi

# This target adds a license copyright header is on every source file that is missing one
.PHONY: add-license
add-license:
	@ADDLICENSEOUT=`addlicense -y "" -c "observIQ, Inc." $(ALL_SRC) 2>&1`; \
		if [ "$$ADDLICENSEOUT" ]; then \
			echo "addlicense FAILED => add License errors:\n"; \
			echo "$$ADDLICENSEOUT\n"; \
			exit 1; \
		else \
			echo "Add License finished successfully"; \
		fi

# This target runs a test release
# Set SUPERVISOR_VERSION to specify the version of the supervisor to retrieve.
.PHONY: release-test
release-test:
	goreleaser release --parallelism 4 --skip=publish --skip=validate --skip=sign --clean --snapshot --verbose

# This target prepares the repository for a release
# Called by goreleaser before building release
# Set VERSION to specify the version of the release. Set SUPERVISOR_VERSION to specify the version of the supervisor to retrieve.
# Example: make release-prep VERSION=v0.1.0 SUPERVISOR_VERSION=v0.1.0
#
# 1. Create a clean release_deps directory
# 2. Create subdirectories for each platform in the release_deps directory.
# 3. Download latest supervisor binaries to the release_deps directory.
# 4. Copy supervisor config files to the release_deps directory for each platform.
# 5. Copy packaging files to the release_deps directory for each platform.
# 6. Add metadata files to the release_deps directory.
.PHONY: release-prep
release-prep:
	@rm -rf release_deps && mkdir -p release_deps
	@mkdir release_deps/darwin && mkdir release_deps/linux && mkdir release_deps/windows
	BIN_DIR=release_deps ./retrieve-supervisor.sh
	@cp -r packaging/darwin/* release_deps/darwin/
	@cp -r packaging/linux/* release_deps/linux/
	@cp -r packaging/windows/* release_deps/windows/
	@cp configs/supervisor_config_darwin.yaml release_deps/darwin/supervisor-config.yaml
	@cp configs/supervisor_config_linux.yaml release_deps/linux/supervisor-config.yaml
	@cp configs/supervisor_config_windows.yaml release_deps/windows/supervisor-config.yaml
	@cp LICENSE release_deps/LICENSE
	@echo '$(VERSION)' > release_deps/VERSION.txt
