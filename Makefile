IMAGE_NAME ?= owncloudci/php:latest

BUILD_NAME ?= PHP
BUILD_VERSION ?= latest
BUILD_DATE ?= $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')

VCS_REF ?= $(git rev-parse --short HEAD)
VCS_URL ?= $(git remote get-url origin)

DOCKER_CMD ?= docker

.PHONY: build
build:
	$(DOCKER_CMD) build --label org.label-schema.name=$(BUILD_NAME) --label org.label-schema.version=$(BUILD_VERSION) --label org.label-schema.build-date=$(BUILD_DATE) --label org.label-schema.vcs-url=$(VCS_URL) --label org.label-schema.vcs-ref=$(VCS_REF) --label org.label-schema.schema-version=1.0 -t $(IMAGE_NAME) .
