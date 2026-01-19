#
# Makefile
#
# The objective of this is to provide a local execution environment that is as close to identical to the CI/CD platform
# as possible. It provides a number of targets that can be used locally by a developer to ensure that tests and builds
# behave consistently and gives the developer an increased amount of confidence that the their code is valid.
#
################################################################################################
#
SHELL := /bin/bash
.DEFAULT_GOAL := help
PWD = $(shell pwd)

################################################################################################
# Environment Variables
################################################################################################

VERSION = $(shell grep version Project.toml | sed 's/version//g;s/"//g;s/ //g;s/=//g')
APP_NAME = $(shell grep name Project.toml | sed 's/name//g;s/"//g;s/ //g;s/=//g')

# AWS settings
AWS_ACCOUNT_ID ?= 438954004210
AWS_REGION ?= ap-southeast-2

# Helm settings
MINIKUBE_ENABLED ?= false
NAMESPACE ?= dev
RELEASE_NAME ?= julia-template-app-service

# Environment type settings
STANDALONE ?= true
ENVIRONMENT ?= nonprod

# Testing Variables 
COVERAGE ?= true
SAVECOV ?= false

# workspace dependent settings
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	IMAGE_NAME := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/or/core/julia-template-app-service
ifdef JULIA_TEMPLATE_APP_SERVICE_IMAGE_TAG
	IMAGE_TAG := $(JULIA_TEMPLATE_APP_SERVICE_IMAGE_TAG)
else
	IMAGE_TAG ?= $(VERSION)
endif
else
	IMAGE_NAME := julia-template-app-service
	IMAGE_TAG := latest
endif

# Workspace settings
ifneq ($(TF_BUILD),True)
	# Local
	COLOUR := yes
	DOCKER_TTY := -t
else
	# Azure Pipelines
	COLOUR := no
	DOCKER_SOCKET := -v /var/run/docker.sock:/var/run/docker.sock
	VERSION_PREFIX := \#\#vso[task.setvariable variable=buildVersion]
    SSH_PUBLIC_KEY := $$(aws ssm get-parameter --name /or/.ssh/id_rsa.pub --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text)
	SSH_PRIVATE_KEY := $$(aws ssm get-parameter --name /or/.ssh/id_rsa --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text)
endif

# Setup the docker command
DOCKER_SHELL := /bin/ash
DOCKER_ENV := $(foreach V, $(filter DOCKER_ENV_%,$(.VARIABLES)), -e $(patsubst DOCKER_ENV_%,%,$(V))="$($V)")
DOCKER_IMAGE ?= julia:1.6.2-alpine3.14
DOCKER_RUN := docker run \
	--rm \
	--interactive \
	-w /docker/$(APP_NAME) \
	-v $(CURDIR):/docker/$(APP_NAME) \
	$(DOCKER_ENV) \
	$(DOCKER_ARGS) \
	$(DOCKER_IMAGE)

define USAGE
The following targets are available:
  make build                   # Build the docker image using the local Julia system image.  
  make build-sysimage          # Build the Julia system image and copy to local files.
  make build-test              # Build the docker image without a Julia system image. Quick to build, slow to run.
  make clean                   # Clean the workspace.
  make deploy                  # Deploy to kubernetes
  make destroy                 # Destroy namespace
  make help                    # Prints out this message.
  make local-setup             # Install all dependencies.
  make register-version        # Registers version in or-core-julia-registry.
  make unit-test               # Runs the unit testing.
  make local-unit-test 		   # Runs the unit testing locally.
  make version                 # Print the package version.

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
.PHONY: local-setup
local-install: check-local-workspace
	julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Register new version in or-sdk repository
.PHONY: register-version
register-version: check-local-workspace
ifneq ($(wildcard ~/.julia/registries/or-core-julia-registry),)
	@if cd ~/.julia/registries/or-core-julia-registry && \
		git pull origin master && \
		git branch $(APP_NAME)-version-v$(VERSION) && \
		git checkout $(APP_NAME)-version-v$(VERSION) && \
		git push origin $(APP_NAME)-version-v$(VERSION) && \
		julia -e 'using Pkg; Pkg.activate(;temp=true); Pkg.add(name="LocalRegistry", version="0.4"); using LocalRegistry; Pkg.develop(path="$(PWD)"); register("$(APP_NAME)", registry="or-core-julia-registry", push=false)' && \
		git push origin $(APP_NAME)-version-v$(VERSION); then \
		cd ~/.julia/registries/or-core-julia-registry && \
			git checkout master && \
			echo "*** New Branch for Registration PR Successfully Created ***"; \
	else \
		cd ~/.julia/registries/or-core-julia-registry && \
			git checkout master && \
			git branch -d $(APP_NAME)-version-v$(VERSION) && \
			git push origin --delete $(APP_NAME)-version-v$(VERSION) && \
			echo "*** Registering Failed - See Log Above ***"; \
	fi
else
	$(error or-core-julia-registry is not installed, please install using LocalRegistry)
endif

################################################################################################
# Common Targets
################################################################################################

# Build a docker image, including build of Julia system image
.PHONY: build
build:
	@echo "Building $(CURDIR)"
ifeq ($(wildcard JuliaAppTemplate.so),)
	@echo "ERROR: No JuliaAppTemplate system image - please run 'make build-sysimage' first"
	@exit 1
else
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	echo "$(SSH_PUBLIC_KEY)" > id_rsa.pub && \
	echo "$(SSH_PRIVATE_KEY)" > id_rsa && \
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -f Dockerfile . --build-arg OPTION=ALREADY_BUILT --ssh default=./id_rsa
else
ifeq ($(shell echo $(MINIKUBE_ENABLED) | tr [:upper:] [:lower:]),true)
	eval $$(minikube -p minikube docker-env) && \
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
else
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -f Dockerfile . --build-arg OPTION=ALREADY_BUILT --ssh default=$(OR_JULIA_REGISTRY_SSH_DIR)
endif
endif
endif

# Build the sysimage
.PHONY: build-sysimage
build-sysimage:
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	echo "$(SSH_PUBLIC_KEY)" > id_rsa.pub && \
	echo "$(SSH_PRIVATE_KEY)" > id_rsa && \
    DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -f Dockerfile . --ssh default=./id_rsa && \
	id=$$(docker create $(IMAGE_NAME):$(IMAGE_TAG)) && \
	mkdir -p pkg && \
	docker cp $$id:/app/JuliaAppTemplate.so ./pkg/JuliaAppTemplate.so && \
	docker cp $$id:/app/Manifest.toml ./pkg/Manifest.toml && \
	docker rm -v $$id && \
	echo $(VERSION) >> pkg/versioninfo.txt
else
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -f Dockerfile . --ssh default=$(OR_JULIA_REGISTRY_SSH_DIR) && \
	id=$$(docker create $(IMAGE_NAME):$(IMAGE_TAG)) && \
	docker cp $$id:/app/JuliaAppTemplate.so ./JuliaAppTemplate.so && \
	docker cp $$id:/app/Manifest.toml ./Manifest.toml && \
	docker rm -v $$id
endif

# Build docker image with no Julia system image
.PHONY: build-test
build-test: check-local-workspace
	@echo "Building $(CURDIR)"
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(IMAGE_TAG)  -f DockerfileBuildTest . --ssh default=$(OR_JULIA_REGISTRY_SSH_DIR)

# Clean the workspace
.PHONY: clean
clean: FILES := Manifest.toml '*.cov' '*-lcov.info' '*.so' 'versioninfo.txt'
clean: check-local-workspace
	@echo "Cleaning $(CURDIR)"
	@for file in $(FILES); do \
		find . -name "$$file" -type f -exec rm -f {} +; \
	done
ifeq ($(shell echo $(MINIKUBE_ENABLED) | tr [:upper:] [:lower:]),true)
	@helm uninstall $(RELEASE_NAME) \
	--namespace $(NAMESPACE)
else
	@CONTAINERS=$(shell docker ps -a --filter ancestor=$(IMAGE_NAME) --format "{{.ID}}") && \
	if [ -n "$${CONTAINERS}" ]; then \
		docker rm $${CONTAINERS}; \
	fi
	@IMAGES=$(shell docker image ls $(IMAGE_NAME) --format "{{.ID}}") && \
	if [ -n "$${IMAGES}" ]; then \
		docker rmi $${IMAGES}; \
	fi
endif

# Run the unit test
.PHONY: unit-test
unit-test: 
COMMANDS := \
	echo \"$(BRANCH_NAME)\" && \
	apk add --update --no-cache openssh && \
	mkdir -m 600 ~/.ssh && \
	echo \"$(SSH_PUBLIC_KEY)\" > ~/.ssh/id_rsa.pub && \
	echo \"$(SSH_PRIVATE_KEY)\" > ~/.ssh/id_rsa && \
	julia -e 'using Pkg; Pkg.Registry.add(\"General\")' && \
	ssh-keyscan dvcs.deloittedigital.com.au >> ~/.ssh/known_hosts && \
	julia -e 'using Pkg; Pkg.Registry.add(RegistrySpec(url=\"ssh://git@dvcs.deloittedigital.com.au:22/core/or-core-julia-registry.git\"))' && \
	julia --color=$(COLOUR) --thread=auto --project=@. -e 'using Pkg; Pkg.test(coverage=true)' && \
	julia --color=$(COLOUR) -e 'using Pkg; Pkg.activate(temp=true); Pkg.add(\"TestingUtils\"); using TestingUtils; run_coverage_report(\"./test\", save_cov=$(SAVECOV))'
unit-test:
	@$(DOCKER_RUN) $(DOCKER_SHELL) -c "$(COMMANDS)"

# run the unit tests locally (assums you have or-core-julia-registry and general-registry)
.PHONY: local-unit-test
local-unit-test:
	@echo Testing locally
	@julia --color=$(COLOUR) --thread=auto --project=@. -e 'using Pkg; Pkg.test(coverage=$(COVERAGE))'
ifeq ($(shell echo $(COVERAGE) | tr [:upper:] [:lower:]),true)
	julia -e 'using Pkg; Pkg.activate(temp=true); Pkg.add("TestingUtils"); using TestingUtils; run_coverage_report("./test", save_cov=$(SAVECOV));'
endif

# Print the version
.PHONY: version
version: COMMANDS := \
	julia -e 'using Pkg; Pkg.add(\"TOML\")' && \
	VERSION=\$$(julia -e 'using TOML; print(TOML.parse(open(\"Project.toml\"))[\"version\"])') && \
	echo \"$(VERSION_PREFIX)\$${VERSION}\"
version:
	@$(DOCKER_RUN) $(DOCKER_SHELL) -c "$(COMMANDS)"

################################################################################################
# Desployment Targets
################################################################################################

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
	--set-string aws.region=$(AWS_REGION) \
	--set-string image.repository=$(IMAGE_NAME) \
	--set-string image.tag=$(IMAGE_TAG) \
	--set-string experimentManager.masterJWT=`aws ssm get-parameter --name /or/experiment-manager/master-jwt --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--values chart/values_$(ENVIRONMENT).yaml \
	--atomic
	@INGRESS=`kubectl get ingress -n $(NAMESPACE) -l app.kubernetes.io/name=graphql-service -o jsonpath='{.items[*].spec.rules[*].host}'` && \
	echo "##vso[task.setvariable variable=graphqlServiceUrl]http://${INGRESS}"
endif
else
ifeq ($(shell echo $(MINIKUBE_ENABLED) | tr [:upper:] [:lower:]),true)
	@eval $$(minikube docker-env) ;\
    $(eval GRAPHQL_LOCAL_MINIKUBE_ENDPOINT=$(shell minikube service graphql-service -n dev --url))
	@echo "Deploying $(CURDIR)"
	@helm upgrade $(RELEASE_NAME) chart \
	--install \
	--create-namespace \
	--namespace $(NAMESPACE) \
	--set-string image.repository=$(IMAGE_NAME) \
	--set-string image.tag=$(IMAGE_TAG) \
	--set-string graphqlLocal.endpoint=$(GRAPHQL_LOCAL_MINIKUBE_ENDPOINT) \
	--values chart/values_local.yaml \
	--atomic
	@echo "Local minikube graphql-service endpoint: $(GRAPHQL_LOCAL_MINIKUBE_ENDPOINT)"
else
	@echo "Deploying $(CURDIR)"
	@docker-compose down --remove-orphans
	@docker-compose up
endif
endif

# Destroy the Namespace
.PHONY: destroy
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

# Update kube conffig
.PHONY: update-kubeconfig
update-kubeconfig:
	@aws sts get-caller-identity \
		--region $(AWS_REGION)
	@aws eks update-kubeconfig \
		--name $(CLIENT)-$(ENVIRONMENT) \
		--region $(AWS_REGION) \
		--role=arn:aws:iam::$(AWS_ACCOUNT_ID):role/trusting-administratoraccess-role
	@kubectl cluster-info
