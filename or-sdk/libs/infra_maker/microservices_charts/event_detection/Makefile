#
# Makefile
#
# The objective of this is to provide a local execution environment that is as close to identical to the CI/CD platform
# as possible. It provides a number of targets that can be used locally by a developer to ensure that tests and builds
# behave consistently and gives the developer an increased amount of confidence that the their code is valid.
#
# To pass a variable to a docker run command, prefix it with DOCKER_ENV_. The variable will be
# passed to docker stripped of the prefix.
#
# In order to enable the integration with TestRail, the or-unit-test-runner repository needs to be checked out into the
# directory unit-test-runner in the project directory (i.e. where this Makefile is). For more information relating to
# the configuration of the unit-test-runner, refer to the unit-test-runner README.
#
################################################################################################
#
SHELL  := /bin/bash
.DEFAULT_GOAL := help

################################################################################################
# Environment Variables
################################################################################################

# AWS settings
AWS_ACCOUNT_ID ?= 438954004210
AWS_REGION ?= ap-southeast-2

# Helm settings
NAMESPACE ?= dev
RELEASE_NAME ?= event-detection-service

# Environment type settings
STANDALONE ?= true
ENVIRONMENT ?= nonprod
CLIENT ?= tfnsw

# EC2 Dev Variables
BRANCH ?= origin/jl-master


# workspace dependent settings
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	IMAGE_NAME := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/or/core/event-detection-service
ifdef EVENT_DETECTION_SERVICE_IMAGE_TAG
	IMAGE_TAG := $(EVENT_DETECTION_SERVICE_IMAGE_TAG)
else
	IMAGE_TAG ?= $(shell grep appVersion chart/Chart.yaml | sed 's/appVersion://g;s/"//g;s/ //g;s/=//g')
endif
else
	IMAGE_NAME := event-detection-service
	IMAGE_TAG := latest
endif

# pip settings
PIP_EXTRA_INDEX_URL ?= https://build:${AZURE_DEVOPS_EXT_PAT}@pkgs.dev.azure.com/dd-managed-services/721248f2-8f57-4990-95af-c4392f87a903/_packaging/or-core-model/pypi/simple/
define PIPCONF
[global]
trusted-host = pypi.python.org
	pypi.org
	files.pythonhosted.org
extra-index-url = $(PIP_EXTRA_INDEX_URL)
endef
export PIPCONF
DOCKER_ENV_PIP_EXTRA_INDEX_URL := $(PIP_EXTRA_INDEX_URL)

# Setup the docker command
DOCKER_ENV := $(foreach V, $(filter DOCKER_ENV_%,$(.VARIABLES)), -e $(patsubst DOCKER_ENV_%,%,$(V))="$($V)")
DOCKER_IMAGE ?= python:3.8
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

  make build                # Build the image.
  make clean                # Clean the workspace.
  make deploy               # Deploy the service.
  make publish              # Publish the image.
  make help                 # Prints out this message.
  make security-test        # Reports the image scan findings.
  make pull-branch			# Dev feature: Pull branch for development on EC2

endef
export USAGE

################################################################################################
# Helper Targets
################################################################################################

.PHONY: check-azure-devops-ext-pat
check-azure-devops-ext-pat:
	@if [ -z "$(AZURE_DEVOPS_EXT_PAT)" ]; then \
		printf "\nERROR: This command requires AZURE_DEVOPS_EXT_PAT to be set.\n\n"; \
		exit 1; \
	fi

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
# CI/CD Targets
################################################################################################

# Build the package
.PHONY: build
build:
	@echo "Building $(CURDIR)"
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	@echo "$$PIPCONF" > pip.conf && \
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) . && \
	rm -f pip.conf
else
	@echo "$$PIPCONF" > pip.conf && \
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) . && \
	rm -f pip.conf
endif


# Clean the workspace
.PHONY: clean
clean: check-local-workspace
	@echo "Cleaning $(CURDIR)"
	@DIRS=".mypy_cache .pytest_cache build dist '*.egg-info' tmp_test" && \
	for dir in $${DIRS}; do \
		find . -name "$$dir" -type d -exec rm -rf {} +; \
	done
	@FILES="output-lint.txt output-unit.xml pip.conf" && \
	for file in $${FILES}; do \
		find . -name "$$file" -type f -exec rm -f {} +; \
	done
	@CONTAINERS=$(shell docker ps -a --filter ancestor=$(IMAGE_NAME) --format "{{.ID}}") && \
	if [ -n "$${CONTAINERS}" ]; then \
		docker rm $${CONTAINERS}; \
	fi
	@IMAGES=$(shell docker image ls $(IMAGE_NAME) --format "{{.ID}}") && \
	if [ -n "$${IMAGES}" ]; then \
		docker rmi $${IMAGES}; \
	fi

# Pull the branch
.PHONY: pull-branch
pull-branch:
	@echo "Pulling branch $(BRANCH)"; \
	git fetch; \
	git checkout -b temp || git checkout temp; \
	git branch -D @{-1} || true; \
	git checkout -t $$BRANCH && \
	git branch -D temp
	@echo "Pulled Branch $(BRANCH)"

# Deploy the microservice using Helm
.PHONY: deploy
deploy: NAMESPACE := $(patsubst %-,%,$(shell echo $(NAMESPACE) | sed 's/refs\/heads\///' | tr [/_] - | tr [:upper:] [:lower:] | cut -c1-50))
deploy:
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	@echo "Deploying $(CURDIR)"
ifeq ($(shell echo $(STANDALONE) | tr [:upper:] [:lower:]),true)
	@helm upgrade $(RELEASE_NAME) chart \
	--install \
	--create-namespace \
	--namespace $(NAMESPACE) \
	--set-string image.repository=$(IMAGE_NAME) \
	--set-string image.tag=$(IMAGE_TAG) \
	--values chart/values_standalone.yaml \
	--wait
	echo "##vso[task.setvariable variable=graphqlServiceUrl]http://graphql-$(NAMESPACE).optimalreality.com.au"
else
	@helm upgrade $(RELEASE_NAME) chart \
	--install \
	--create-namespace \
	--namespace $(NAMESPACE) \
	--set-string image.repository=$(IMAGE_NAME) \
	--set-string image.tag=$(IMAGE_TAG) \
	--set-string experimentManager.masterJWT=`aws ssm get-parameter --name /or/experiment-manager/master-jwt --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--values chart/values_$(ENVIRONMENT).yaml \
	--set-string AWS_ACCESS_KEY_ID=`aws ssm get-parameter --name /tpoc/aws_access_key_id --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--set-string AWS_SECRET_ACCESS_KEY=`aws ssm get-parameter --name /tpoc/aws_secret_access_key --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--atomic
	@INGRESS=`kubectl get ingress -n $(NAMESPACE) -l app.kubernetes.io/name=graphql-service -o jsonpath='{.items[*].spec.rules[*].host}'` && \
	echo "##vso[task.setvariable variable=graphqlServiceUrl]http://${INGRESS}"
endif
else
	@echo "Deploying $(CURDIR)"
	@docker-compose down --remove-orphans
	@docker-compose up
endif

destroy: NAMESPACE := $(patsubst %-,%,$(shell echo $(NAMESPACE) | sed 's/refs\/heads\///' | tr [/_] - | tr [:upper:] [:lower:] | cut -c1-50))
destroy: check-cicd-workspace
ifeq ($(shell echo $(STANDALONE) | tr [:upper:] [:lower:]),true)
	@echo "Destroying $(CURDIR)"
	@kubectl delete namespace --wait=true --timeout=300s $(NAMESPACE)
else
	@echo "Skipping $(CURDIR)"
endif

# Authenticates with a private docker registry
.PHONY: docker-login
docker-login: check-cicd-workspace
	@aws ecr get-login-password --region $(AWS_REGION) | \
	docker login --username AWS --password-stdin $(shell sed 's/\/.*//g'<<< $(IMAGE_NAME))


# Publish the image
.PHONY: publish
publish: check-cicd-workspace
	@docker push $(IMAGE_NAME):$(IMAGE_TAG)

# Pull the image
.PHONY: pull
pull: check-cicd-workspace
	@docker pull $(IMAGE_NAME):$(IMAGE_TAG)

# Run the security test (report only)
.PHONY: security-test
security-test: check-cicd-workspace
	@echo "NOTICE: This is a work in progress and is for reporting only"
	@aws ecr wait image-scan-complete \
		--repository-name $(shell sed 's/^[^\/]*\///g' <<< $(IMAGE_NAME)) \
		--image-id imageTag=$(IMAGE_TAG) \
		--region $(AWS_REGION) && \
	aws ecr describe-image-scan-findings \
		--repository-name $(shell sed 's/^[^\/]*\///g' <<< $(IMAGE_NAME)) \
		--image-id imageTag=$(IMAGE_TAG) \
		--region $(AWS_REGION)

.PHONY: update-kubeconfig
update-kubeconfig:
	@aws sts get-caller-identity \
		--region $(AWS_REGION)
	@aws eks update-kubeconfig \
		--name asa-atm-$(ENVIRONMENT)-optimalreality \
		--region $(AWS_REGION)
	@kubectl cluster-info