IMAGE_NAME ?= owncloudci/php:latest

VERSION ?= latest
BUILD_DATE ?= $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')
VCS_REF ?= $(git rev-parse --short HEAD)

DOCKER_CMD ?= docker

.PHONY: build
build:
	$(DOCKER_CMD) build --build-arg VERSION=$(VERSION) --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VCS_REF=$(VCS_REF) -t $(IMAGE_NAME) .
