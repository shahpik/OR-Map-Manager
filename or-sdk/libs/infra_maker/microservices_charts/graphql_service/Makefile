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

# AWS settings
AWS_ACCOUNT_ID ?= 438954004210
AWS_REGION ?= ap-southeast-2

# Helm settings
MINIKUBE_ENABLED ?= false
NAMESPACE ?= dev
RELEASE_NAME ?= graphql-service

# Environment type settings
STANDALONE ?= true
ENVIRONMENT ?= nonprod
CLIENT ?= tfnsw

# workspace dependent settings
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	IMAGE_NAME := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/asa/atm/graphql-service
ifdef GRAPHQL_SERVICE_IMAGE_TAG
	IMAGE_TAG := $(GRAPHQL_SERVICE_IMAGE_TAG)
else
	IMAGE_TAG ?= $(shell grep appVersion chart/Chart.yaml | sed 's/appVersion://g;s/"//g;s/ //g;s/=//g')
endif
else
	# TODO remove the fake settings for dynamodb-local and add to values-minikube.yaml
	AWS_ACCESS_KEY_ID := fake
	AWS_SECRET_ACCESS_KEY := key
	IMAGE_NAME := graphql-service
	IMAGE_TAG := latest
endif

# minikube settings
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
ifdef TARGET_URL
ifeq ($(shell echo $(ENVIRONMENT) | tr [:upper:] [:lower:]),nonprod)
	DOCKER_ARGS := \
	--add-host $(shell sed 's/.*\///g' <<< $(TARGET_URL)):10.80.165.81 \
	--add-host $(shell sed 's/.*\///g' <<< $(TARGET_URL)):10.80.166.122 \
	--add-host $(shell sed 's/.*\///g' <<< $(TARGET_URL)):10.80.167.206
else
	DOCKER_ARGS := \
	--add-host $(shell sed 's/.*\///g' <<< $(TARGET_URL)):10.80.169.165 \
	--add-host $(shell sed 's/.*\///g' <<< $(TARGET_URL)):10.80.170.120 \
	--add-host $(shell sed 's/.*\///g' <<< $(TARGET_URL)):10.80.171.213
endif
endif
else
ifeq ($(shell echo $(MINIKUBE_ENABLED) | tr [:upper:] [:lower:]),true)
	TARGET_URL ?= http://graphql.$(NAMESPACE)
	DOCKER_ARGS := -t --add-host $(shell sed 's/.*\///g' <<< $(TARGET_URL)):$(shell minikube ip)
else
	TARGET_URL ?= http://host.docker.internal:5100
	DOCKER_ARGS := -t
endif
endif

# integration test settings
TEST_RAIL_ENABLED ?= false
DOCKER_ENV_TARGET_URL := $(TARGET_URL)
ifeq ($(shell echo $(TEST_RAIL_ENABLED) | tr [:upper:] [:lower:]),true)
	TEST_RAIL_ARGS := \
		--testrail \
		--tr-close-on-complete \
		--tr-config=testrail.cfg \
		--tr-email=$(TEST_RAIL_USER_NAME) \
		--tr-password=$(TEST_RAIL_USER_KEY) \
		--tr-testrun-name=$(TEST_RUN_NAME)
endif

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
  make integration-test     # Run the integration tests.
  make publish              # Publish the image.
  make security-test        # Reports the image scan findings.
  make help                 # Prints out this message.

The following environment variables (either defined and exported or passed on the command line as in
the following examples) can be used to control the execution:

  MINIKUBE_ENABLED          # Used to enable testing against a minikube endpoint url.
  TARGET_URL                # The endpoint url to run tests against.
  TEST_RAIL_ENABLED         # Used to enable TestRail reporting.
  TEST_RAIL_USER_NAME       # The test rail user id.
  TEST_RAIL_USER_KEY        # The test rail key.
  TEST_RUN_NAME             # The test run name.

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
	@echo "Building $(CURDIR)"
ifeq ($(shell echo $(TF_BUILD) | tr [:upper:] [:lower:]),true)
	@docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
else
ifeq ($(shell echo $(MINIKUBE_ENABLED) | tr [:upper:] [:lower:]),true)
	@eval $$(minikube -p minikube docker-env) && \
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
else
	@docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
endif
endif

# Remove containers and images
.PHONY: clean
clean: check-local-workspace
	@echo "Cleaning $(CURDIR)"
ifeq ($(shell echo $(MINIKUBE_ENABLED) | tr [:upper:] [:lower:]),true)
	@helm uninstall $(RELEASE_NAME) \
	--namespace $(NAMESPACE) || true
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

# TODO: secrets need to be less rigidly defined - branch namespaces may not require ssm
# Install/upgrade the microservice
# TODO: To replace local postgreql container with RDS, set postgreql password and username (in the 'else' block starting line 207)- add the following to helm options:
# --set-string postgresql.password=`aws ssm get-parameter --name /asa/atm/$(ENVIRONMENT)/optimalreality/postgresql_password --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text`
# --set-string postgresql.username=`aws ssm get-parameter --name /asa/atm/$(ENVIRONMENT)/optimalreality/postgresql_username --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text`
# TODO: To replace local dynamodb with actual DynamoDB, remove the following from the same block of code:
# ALSO remove --set-string aws.dynamodbEndpoint=http://dynamodb.$(NAMESPACE)
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
	--set-string aws.region=$(AWS_REGION) \
	--set-string image.repository=$(IMAGE_NAME) \
	--set-string image.tag=$(IMAGE_TAG) \
	--set-string ingress.enabled=true \
	--set-string ingress.hosts[0].host=graphql-$(NAMESPACE).optimalreality.com.au \
	--set-string ingress.hosts[0].paths[0].path=/ \
	--set-string postgresql.endpoint=postgresql.$(NAMESPACE):5432 \
	--values chart/values_standalone.yaml \
	--wait
	echo "##vso[task.setvariable variable=graphqlServiceUrl]http://graphql-$(NAMESPACE).optimalreality.com.au"
else
	@echo "Repository $(IMAGE_NAME) $(IMAGE_TAG)"
	@set -euo pipefail && \
	helm upgrade $(RELEASE_NAME) chart \
	--install \
	--create-namespace \
	--namespace $(NAMESPACE) \
	--set-string aws.region=$(AWS_REGION) \
	--set-string image.repository=$(IMAGE_NAME) \
	--set-string image.tag=$(IMAGE_TAG) \
	--values chart/values_$(ENVIRONMENT).yaml \
	--set-string experimentManager.masterJWT=`aws ssm get-parameter --name /or/experiment-manager/master-jwt --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--set-string tpoc.aws_access_key_id=`aws ssm get-parameter --name /tpoc/aws_access_key_id --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--set-string tpoc.aws_secret_access_key=`aws ssm get-parameter --name /tpoc/aws_secret_access_key --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--set-string postgresqlSimulation.password=`aws ssm get-parameter --name /$(CLIENT)/$(ENVIRONMENT)/optimalreality/postgresql_password --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--set-string postgresqlSimulation.username=`aws ssm get-parameter --name /$(CLIENT)/$(ENVIRONMENT)/optimalreality/postgresql_username --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--set-string postgresql.password=`aws ssm get-parameter --name /$(CLIENT)/$(ENVIRONMENT)/optimalreality/master_password --region $(AWS_REGION) --query 'Parameter.Value' --with-decryption --output text` \
	--atomic
	@INGRESS=`kubectl get ingress -n $(NAMESPACE) -l app.kubernetes.io/name=$(RELEASE_NAME) -o jsonpath='{.items[*].spec.rules[*].host}'` && \
	echo "##vso[task.setvariable variable=graphqlServiceUrl]http://${INGRESS}"
endif
else
ifeq ($(shell echo $(MINIKUBE_ENABLED) | tr [:upper:] [:lower:]),true)
	@echo "Deploying $(CURDIR)"
	@helm upgrade $(RELEASE_NAME) chart \
	--install \
	--create-namespace \
	--namespace $(NAMESPACE) \
	--set-string aws.accessKeyId=$(AWS_ACCESS_KEY_ID) \
	--set-string aws.dynamodbEndpoint=http://dynamodb.$(NAMESPACE) \
	--set-string aws.region=$(AWS_REGION) \
	--set-string aws.secretAccessKey=$(AWS_SECRET_ACCESS_KEY) \
	--set-string image.repository=$(IMAGE_NAME) \
	--set-string image.tag=$(IMAGE_TAG) \
	--set-string ingress.enabled=true \
	--set-string ingress.hosts[0].host=graphql.$(NAMESPACE) \
	--set-string ingress.hosts[0].paths[0].path=/ \
	--set-string postgresql.endpoint=postgresql.$(NAMESPACE):5432 \
	--values chart/values_local.yaml \
	--wait \
	--atomic
	@GRAPHQL_LOCAL_MINIKUBE_ENDPOINT=$$(minikube service graphql-service -n dev --url) ;\
	kubectl set env deployment graphql-service -n dev GRAPHQL_LOCAL_MINIKUBE_ENDPOINT=$$GRAPHQL_LOCAL_MINIKUBE_ENDPOINT ;\
	echo Local minikube graphql-service endpoint: $$GRAPHQL_LOCAL_MINIKUBE_ENDPOINT
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

# Run all the integration tests
.PHONY: integration-test
integration-test: COMMANDS := \
	python3 -m pip install -r requirements-integration.txt && \
	python3 -m pytest $(TEST_RAIL_ARGS) -p no:cacheprovider --color=yes -ra integration_tests
integration-test:
	@$(DOCKER_RUN) /bin/bash -c "$(COMMANDS)"

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
