################################################################################################
#
SHELL  := /bin/bash
.DEFAULT_GOAL := help

################################################################################################
# Environment Variables
################################################################################################

# workspace dependent settings
ifneq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	DOCKER_ARGS := -t
endif

# coverage test rail settings
TEST_RAIL_ENABLED ?= false
DOCKER_ENV_TARGET_URL := $(TARGET_URL)
ifeq ($(shell echo $(TEST_RAIL_ENABLED) | tr [:upper:] [:lower:]),true)
	TEST_RAIL_COVERAGE_ARGS := \
		--testrail \
		--tr-close-on-complete \
		--tr-config=coverage_tests/testrail.cfg \
		--tr-email=$(TEST_RAIL_USER_NAME) \
		--tr-password=$(TEST_RAIL_USER_KEY) \
		--tr-testrun-name=$(TEST_RUN_NAME)
endif

# lint test rail settings
TEST_RAIL_ENABLED ?= false
DOCKER_ENV_TARGET_URL := $(TARGET_URL)
ifeq ($(shell echo $(TEST_RAIL_ENABLED) | tr [:upper:] [:lower:]),true)
	TEST_RAIL_LINT_ARGS := \
		--testrail \
		--tr-close-on-complete \
		--tr-config=lint_tests/testrail.cfg \
		--tr-email=$(TEST_RAIL_USER_NAME) \
		--tr-password=$(TEST_RAIL_USER_KEY) \
		--tr-testrun-name=$(TEST_RUN_NAME)
endif

# Setup the docker command
DOCKER_ENV := $(foreach V, $(filter DOCKER_ENV_%,$(.VARIABLES)), -e $(patsubst DOCKER_ENV_%,%,$(V))="$($V)")
DOCKER_IMAGE ?= python:3.9
DOCKER_RUN := docker run \
	--rm \
	--interactive \
	-w /docker \
	-v $(CURDIR):/docker \
	$(DOCKER_ENV) \
	$(DOCKER_ARGS) \
	$(DOCKER_IMAGE)

define USAGE
The following targets are available:

  make build                # Builds the package.
  make clean                # Cleans the workspace.
  make local-install        # Installs the package locally.
  make local-setup          # Sets up the local workspace.
  make publish              # Publish the package to Azure Artifacts.
  make help                 # Prints out this message.
endef
export USAGE

################################################################################################
# Helper Targets
################################################################################################

# Checks that it's a local development environment
.PHONY: check-cicd-workspace
check-cicd-workspace:
	@if [ -z "$(TF_BUILD)" ]; then \
		printf "\nERROR: This command is to be run in CI/CD only.\n\n"; \
		exit 1; \
  	fi

# Checks that it's a local development environment
.PHONY: check-local-workspace
check-local-workspace:
	@if [ -n "$(TF_BUILD)" ]; then \
		printf "\nERROR: This command is to be run locally only.\n\n"; \
		exit 1; \
  	fi

# Print out the usage information
help:
	@printf "\n$$USAGE\n\n"

################################################################################################
# Local Development Targets
################################################################################################

# Install the package
.PHONY: local-install
local-install: check-local-workspace
	@python3 setup.py install

# Installs all the packages required for the local workspace
.PHONY: local-setup
local-setup: check-local-workspace
	@python3 -m pip install -r requirements-setup.txt && \
	python3 -m pip install -r requirements.txt

################################################################################################
# Common Targets
################################################################################################

# Build the package
.PHONY: build
build: COMMANDS := \
	rm -f dist/* && \
	python3 -m pip install -r requirements-setup.txt && \
	python3 setup.py $(SETUP_ARGS) sdist bdist_wheel
build:
	@$(DOCKER_RUN) /bin/bash -c "$(COMMANDS)"

# Clean the local workspace
.PHONY: clean
clean: check-local-workspace
	@echo "Cleaning $(CURDIR)"
	@DIRS="__pycache__ .mypy_cache .pytest_cache build dist '*.egg-info'" && \
	for dir in $${DIRS}; do \
		find . -name "$$dir" -type d -exec rm -rf {} +; \
	done

.PHONY: deploy
deploy:
	@printf "Deployment not required for this package\n"

# Publish the package to Azure Artifacts
.PHONY: publish
publish: COMMANDS := \
	python3 -m pip install -r requirements-publish.txt && \
	twine upload -r \$$REPOSITORY --config-file .pypirc --disable-progress-bar dist/*.whl --verbose
publish: check-cicd-workspace
	@$(DOCKER_RUN) /bin/bash -c "$(COMMANDS)"
