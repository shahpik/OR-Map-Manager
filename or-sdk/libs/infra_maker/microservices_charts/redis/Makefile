#
# Makefile
#
# The objective of this is to provide a local execution environment that is as close to identical to the CI/CD platform
# as possible. It provides a number of targets that can be used locally by a developer to ensure that tests and builds
# behave consistently and gives the developer an increased amount of confidence that the their code is valid.
#
################################################################################################
#
SHELL  := /bin/bash
.DEFAULT_GOAL := help

################################################################################################
# Environment Variables
################################################################################################

# Helm settings
MINIKUBE_ENABLED ?= false
NAMESPACE ?= dev
RELEASE_NAME ?= redis

# Environment type settings
STANDALONE ?= true
ENVIRONMENT ?= nonprod
CLIENT ?= tfnsw

define USAGE
The following targets are available:

  make clean                # Clean the workspace.
  make deploy               # Deploy the service.
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
# Common Targets
################################################################################################

# Build the image
.PHONY: build
build:
	@echo "Skipping $(CURDIR)"

# Uninstall the microservice
.PHONY: clean
clean: check-local-workspace
ifeq ($(shell echo $(MINIKUBE_ENABLED) | tr [:upper:] [:lower:]),true)
	@echo "Cleaning $(CURDIR)"
	@helm uninstall $(RELEASE_NAME) \
	--namespace $(NAMESPACE)
else
	@echo "Skipping $(CURDIR)"
endif

# Install/upgrade the microservice
.PHONY: deploy
deploy: NAMESPACE := $(patsubst %-,%,$(shell echo $(NAMESPACE) | sed 's/refs\/heads\///' | tr [/_] - | tr [:upper:] [:lower:] | cut -c1-50))
deploy:
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
ifeq ($(shell echo $(STANDALONE) | tr [:upper:] [:lower:]),true)
	@helm upgrade $(RELEASE_NAME) chart \
	--install \
	--create-namespace \
	--namespace $(NAMESPACE) \
	--wait
else
	@echo "Skipping $(CURDIR)"
endif
else
ifeq ($(shell echo $(MINIKUBE_ENABLED) | tr [:upper:] [:lower:]),true)
	@helm upgrade $(RELEASE_NAME) chart \
	--install \
	--create-namespace \
	--namespace $(NAMESPACE) \
	--atomic
else
	@echo "Deploying $(CURDIR)"
	@docker-compose down --remove-orphans
	@docker-compose up
endif
endif