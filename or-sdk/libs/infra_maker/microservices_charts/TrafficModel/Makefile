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
################################################################################################
#
SHELL := /bin/bash
.DEFAULT_GOAL := help

################################################################################################
# Environment Variables
################################################################################################

VERSION = $(shell grep appVersion chart/Chart.yaml | sed 's/appVersion://g;s/"//g;s/ //g;s/=//g')
# AWS settings
AWS_ACCOUNT_ID ?= 438954004210
AWS_REGION ?= ap-southeast-2

# Helm settings
MINIKUBE_ENABLED ?= false
NAMESPACE ?= dev
RELEASE_NAME ?= traffic-model-service

# Environment type settings
STANDALONE ?= true
ENVIRONMENT ?= nonprod
CLIENT ?= tfnsw

# workspace dependent settings
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	IMAGE_NAME := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/asa/core/traffic-model-service
ifdef TRAFFIC_MODEL_SERVICE_IMAGE_TAG
	IMAGE_TAG := $(TRAFFIC_MODEL_SERVICE_IMAGE_TAG)
else
	IMAGE_TAG ?= $(VERSION)
endif
else
	IMAGE_NAME := traffic-model-service
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
endif

# Setup the docker command
SCHEDULE_GEN_DIR = $(addprefix $(dir $(CURDIR)), ScheduleGeneration)
DOCKER_ENV := $(foreach V, $(filter DOCKER_ENV_%,$(.VARIABLES)), -e $(patsubst DOCKER_ENV_%,%,$(V))=\"$($V)\")
DOCKER_IMAGE ?= julia:1.6.2-alpine3.14
DOCKER_RUN := docker run \
	--rm \
	-w /docker/TrafficModel \
	$(DOCKER_ENV) \
	-v $(CURDIR):/docker/TrafficModel \
	-v $(SCHEDULE_GEN_DIR):/docker/ScheduleGeneration \
	$(DOCKER_SOCKET) -i $(DOCKER_TTY) $(DOCKER_IMAGE)

# The help/usage information
define USAGE
The following targets are available:

  make build                # Build the image.
  make build-app            # Build a standalone app (not currently working).
  make build-sysimage       # Build the Julia system image.
  make build-test           # Build the docker image with no precompilation. Quick to build, slow to run.
  make clean                # Clean local workspace.
  make help                 # Prints out this message.
  make local-setup          # Sets up the local workspace for development.
  make register-version     # Registers version in or-core-julia-registry.
  make unit-test            # Runs the unit testing.
  make version              # Print the package version.

endef
export USAGE

################################################################################################
# Helper Targets
################################################################################################

# Checks that it's an azure pipelines environment
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

# Installs all the packages required for the local workspace
.PHONY: local-setup
local-setup: check-local-workspace
	@julia --color=$(COLOUR) --project=@. -e 'using Pkg; Pkg.instantiate()'

.PHONY: register-version
register-version: check-local-workspace
ifneq ($(wildcard ~/.julia/registries/or-core-julia-registry),)
	julia --project=~/.julia/environments/registry-env -e 'using Pkg; Pkg.develop(path=pwd())' && \
	cd ~/.julia/registries/or-core-julia-registry && \
		git pull origin master && \
		git branch TrafficModel-version-v$(VERSION) && \
		git checkout TrafficModel-version-v$(VERSION) && \
		git push origin TrafficModel-version-v$(VERSION) && \
		julia --project=~/.julia/environments/registry-env -e 'using Pkg; Pkg.add("LocalRegistry"); using LocalRegistry; register("TrafficModel")' && \
		git push origin TrafficModel-version-v$(VERSION) && \
		git checkout master
else
	$(error or-core-julia-registry is not installed, please install using LocalRegistry)
endif

################################################################################################
# Common Targets
################################################################################################

# Build the image
.PHONY: build
build:
	@echo "Building $(CURDIR)"
ifeq ($(wildcard TrafficModel.so),)
	@echo "ERROR: No TrafficModel system image - please run 'make build-sysimage' first"
	@exit 1
else
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	echo $(SSH_PUBLIC_KEY) > id_rsa.pub && \
    chmod og-rwx id_rsa.pub && \
	echo -e "${SSH_PRIVATE_KEY}" | sed 's/\_/\'$\'n/g' > id_rsa && \
    chmod og-rwx id_rsa && \
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -f Dockerfile . --build-arg OPTION=LOCAL --ssh default=./id_rsa
else
ifeq ($(shell echo $(MINIKUBE_ENABLED) | tr [:upper:] [:lower:]),true)
	eval $$(minikube -p minikube docker-env) && \
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
else
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -f Dockerfile . --build-arg OPTION=LOCAL --ssh default=$(OR_JULIA_REGISTRY_SSH_DIR)
endif
endif
endif

# Build a docker image containing a Julia Application (as defined by PackageCompiler.jl)
.PHONY: build-app
build-app: COMMANDS := \
	apt-get update -y && \
	apt-get install -y rsync && \
	apt-get install -y gcc && \
	julia --project=@. deploy/packagecompile.jl APP && \
	cd .. && \
	rsync -a --delete TrafficModelCompiled app
build-app: 
	@echo "Building app at $(CURDIR)"
	@$(DOCKER_RUN) /bin/bash -c "$(COMMANDS)"

# Build the sysimage in a docker container and copy to local files
.PHONY: build-sysimage
build-sysimage:
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	echo $(SSH_PUBLIC_KEY) > id_rsa.pub && \
    chmod og-rwx id_rsa.pub && \
	echo -e "${SSH_PRIVATE_KEY}" | sed 's/\_/\'$\'n/g' > id_rsa && \
    chmod og-rwx id_rsa && \
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -f Dockerfile . --ssh default=./id_rsa && \
	id=$$(docker create $(IMAGE_NAME):$(IMAGE_TAG)) && \
	mkdir -p pkg && \
	docker cp $$id:/app/TrafficModel.so ./pkg/TrafficModel.so && \
	docker cp $$id:/app/Manifest.toml ./pkg/Manifest.toml && \
	docker rm -v $$id && \
	echo $(VERSION) >> pkg/versioninfo.txt
else
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -f Dockerfile . --ssh default=$(OR_JULIA_REGISTRY_SSH_DIR) && \
	id=$$(docker create $(IMAGE_NAME):$(IMAGE_TAG)) && \
	docker cp $$id:/app/TrafficModel.so ./TrafficModel.so && \
	docker cp $$id:/app/Manifest.toml ./Manifest.toml && \
	docker rm -v $$id
endif

# Build the docker image without any package compiling
.PHONY: build-test
build-test: check-local-workspace
	@echo "Building $(CURDIR)"
	cd .. && \
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -f TrafficModel/DockerfileBuildTest . --ssh default=$(OR_JULIA_REGISTRY_SSH_DIR)

# Clean the workspace
.PHONY: clean
clean: FILES := Manifest.toml '*.cov' '*-lcov.info' '*.so' '*.xml'
clean:
	@echo "Cleaning $(CURDIR)"
	@for dir in $(DIRS); do \
		find . -name "$$dir" -type d -exec rm -rf {} +; \
	done
	@for file in $(FILES); do \
		find . -name "$$file" -type f -exec rm -f {} +; \
	done

# Run the unit test
.PHONY: unit-test
unit-test: check-cicd-workspace
COMMANDS := \
	apt-get update -y && \
	apt-get install -y unzip && \
	mkdir -p ~/.ssh && \
	echo $(SSH_PUBLIC_KEY) > ~/.ssh/id_rsa.pub && \
    chmod og-rwx ~/.ssh/id_rsa.pub && \
	echo -e "${SSH_PRIVATE_KEY}" | sed 's/\_/\'$\'n/g' > ~/.ssh/id_rsa && \
    chmod og-rwx ~/.ssh/id_rsa && \
	julia -e 'using Pkg; pkg\"registry add https://github.com/JuliaRegistries/General/\"' && \
	julia -e 'using Pkg; pkg\"registry add ssh://git@dvcs.deloittedigital.com.au:22/core/or-core-julia-registry.git\"' && \
	unzip -j data/sydney_validation_demo_data.zip -d data && \
	julia --color=$(COLOUR) --project=@. -e 'using Pkg; Pkg.test()'
unit-test:
	@$(DOCKER_RUN) /bin/bash -c "$(COMMANDS)"

# Print the version
.PHONY: version
version: COMMANDS := \
	julia -e 'using Pkg; Pkg.add(\"TOML\")' && \
	VERSION=\$$(julia -e 'using TOML; print(TOML.parse(open(\"Project.toml\"))[\"version\"])') && \
	echo \"$(VERSION_PREFIX)\$${VERSION}\"
version:
	@$(DOCKER_RUN) /bin/bash -c "$(COMMANDS)"

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
	--values chart/values_$(ENVIRONMENT).yaml \
	--set-string postgresqlSimulation.password=`aws ssm get-parameter --name /$(CLIENT)/$(ENVIRONMENT)/optimalreality/postgresql_password --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--set-string postgresqlSimulation.username=`aws ssm get-parameter --name /$(CLIENT)/$(ENVIRONMENT)/optimalreality/postgresql_username --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--set-string tpoc.aws_access_key_id=`aws ssm get-parameter --name /tpoc/aws_access_key_id --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--set-string tpoc.aws_secret_access_key=`aws ssm get-parameter --name /tpoc/aws_secret_access_key --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--set-string experimentManager.masterJWT=`aws ssm get-parameter --name /or/experiment-manager/master-jwt --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
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

.PHONY: update-kubeconfig
update-kubeconfig:
	@aws sts get-caller-identity \
		--region $(AWS_REGION)
	@aws eks update-kubeconfig \
		--name asa-atm-$(ENVIRONMENT)-optimalreality \
		--region $(AWS_REGION)
	@kubectl cluster-info