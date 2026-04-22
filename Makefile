.DEFAULT_GOAL := help
SHELL := /bin/bash

XCODEBUILD := xcodebuild -project VoiceScribe.xcodeproj -scheme VoiceScribe
DEV_BUILD_DIR := build/dev
RELEASE_BUILD_DIR := build/release
DIST_DIR := dist
APP_NAME := VoiceScribe.app
DEBUG_APP_PATH := $(DEV_BUILD_DIR)/Build/Products/Debug/$(APP_NAME)
RELEASE_APP_PATH := $(RELEASE_BUILD_DIR)/Build/Products/Release/$(APP_NAME)
ARCHIVE_PATH := $(RELEASE_BUILD_DIR)/VoiceScribe.xcarchive
XCODEBUILD_EXTRA_FLAGS :=

ifeq ($(CI),true)
XCODEBUILD_EXTRA_FLAGS += CODE_SIGN_IDENTITY="-"
XCODEBUILD_EXTRA_FLAGS += CODE_SIGNING_REQUIRED=NO
XCODEBUILD_EXTRA_FLAGS += CODE_SIGNING_ALLOWED=NO
endif

.PHONY: help test build dev release archive demo clean can-release _require-xcodebuild

##@ Development

test: _require-xcodebuild ## Run the XCTest suite
	@$(XCODEBUILD) test -configuration Debug $(XCODEBUILD_EXTRA_FLAGS)

build: _require-xcodebuild ## Build the app in Debug configuration
	@$(XCODEBUILD) build -configuration Debug $(XCODEBUILD_EXTRA_FLAGS)

dev: _require-xcodebuild ## Build and open a local Debug app from build/dev
	@echo "==> Building Debug..."
	@$(XCODEBUILD) -configuration Debug -derivedDataPath "$(DEV_BUILD_DIR)" -quiet build
	@if [ ! -d "$(DEBUG_APP_PATH)" ]; then echo "ERROR: $(APP_NAME) not found at $(DEBUG_APP_PATH)"; exit 1; fi
	@echo "==> Opening $(DEBUG_APP_PATH)..."
	@open "$(DEBUG_APP_PATH)"

demo: _require-xcodebuild ## Launch the interactive demo mode
	@bash scripts/demo.sh

##@ Release

archive: _require-xcodebuild ## Archive the release build into build/release
	@echo "==> Archiving Release..."
	@$(XCODEBUILD) archive -configuration Release -archivePath "$(ARCHIVE_PATH)"
	@echo "==> Archive created: $(ARCHIVE_PATH)"

release: _require-xcodebuild ## Build the release app and copy it into dist/
	@echo "==> Building Release..."
	@$(XCODEBUILD) -configuration Release -derivedDataPath "$(RELEASE_BUILD_DIR)" -quiet build
	@if [ ! -d "$(RELEASE_APP_PATH)" ]; then echo "ERROR: $(APP_NAME) not found at $(RELEASE_APP_PATH)"; exit 1; fi
	@mkdir -p "$(DIST_DIR)"
	@rm -rf "$(DIST_DIR)/$(APP_NAME)"
	@cp -R "$(RELEASE_APP_PATH)" "$(DIST_DIR)/$(APP_NAME)"
	@echo "==> Copied to: $(DIST_DIR)/$(APP_NAME)"

can-release: test build ## Run the current CI-safe verification suite

##@ Maintenance

clean: _require-xcodebuild ## Remove generated artifacts and clean Xcode outputs
	@rm -rf build dist
	@$(XCODEBUILD) clean

##@ Help

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_\-\/]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

_require-xcodebuild:
	@command -v xcodebuild >/dev/null || { echo "xcodebuild is required"; exit 1; }
