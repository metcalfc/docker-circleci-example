# BuildKit is a next generation container image builder. You can enable it using
# an environment variable or using the Engine config, see:
# https://docs.docker.com/develop/develop-images/build_enhancements/#to-enable-buildkit-builds
export DOCKER_BUILDKIT=1

GIT_TAG?=$(shell git rev-parse --short HEAD)
ifeq ($(GIT_TAG),)
	GIT_TAG=edge
endif

# Docker image tagging:
HUB_USER?=metcalfc

# When you create your secret use the DockerHub in the name and this will find it
HUB_PULL_SECRET?=$(shell docker secret list | grep arn | grep DockerHub | cut -f1 -d' ')
REPO?=docker-circleci-example
TAG?=${GIT_TAG}
DEV_IMAGE?=${REPO}:latest
PROD_IMAGE?=${HUB_USER}/${REPO}:${TAG}
BUILDX_PLATFORMS?=linux/amd64,linux/arm64,linux/riscv64,linux/ppc64le,linux/s390x,linux/386,linux/arm/v7,linux/arm/v6

# Local development happens here!
# This starts your application and bind mounts the source into the container so
# that changes are reflected in real time.
# Once you see the message "Running on http://0.0.0.0:5000/", open a Web browser at
# http://localhost:5000
.PHONY: dev
all: dev
dev:
	@COMPOSE_DOCKER_CLI_BUILD=1 docker-compose -f docker-compose.dev.yml up --build

# Run the unit tests.
.PHONY: build-test unit-test test
unit-test:
	@docker --context default build --progress plain --target test ./app

test: unit-test

# Build a production image for the application.
.PHONY: build
build:
	@docker --context default build --target prod --tag ${PROD_IMAGE} ./app

# Push the production image to a registry.
.PHONY: push
push:
	@docker --context default push ${PROD_IMAGE}

# Run the production image locally
.PHONY: deploy run logs down
run:
	PROD_IMAGE=${PROD_IMAGE} docker-compose -f docker-compose.yml up -d
logs:
	PROD_IMAGE=${PROD_IMAGE} docker-compose -f docker-compose.yml logs
down:
	PROD_IMAGE=${PROD_IMAGE} docker-compose -f docker-compose.yml down

# Run the production image either via aci or ecs
deploy: build push check-env
	HUB_PULL_SECRET=${HUB_PULL_SECRET} PROD_IMAGE=${PROD_IMAGE} docker compose up

# Remove the dev container, dev image, test image, and clear the builder cache.
.PHONY: clean
clean:
	@docker-compose -f docker-compose.dev.yml down
	@docker rmi ${DEV_IMAGE} || true
	@docker builder prune --force --filter type=exec.cachemount --filter=unused-for=24h

.PHONY: check-env
check-env:
ifndef HUB_PULL_SECRET
	$(error HUB_PULL_SECRET is undefined. Use docker ecs secret ls to find the ARN)
endif

.PHONY: cross-build
cross-build:
	@docker buildx create --name mybuilder --use
	@docker buildx build --platform ${BUILDX_PLATFORMS} -t ${PROD_IMAGE} --push ./app
