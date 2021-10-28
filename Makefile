UTILS_PATH := build-utils
SERVICE_NAME := riak-base
BUILD_IMAGE_TAG := 25c031edd46040a8745334570940a0f0b2154c5c
PORTAGE_REF := 66ba7ec32af9115d68c1cf707e5f95ce8304bc53
OVERLAYS_RBKMONEY_REF := 8ca2cde4d5781b71c289aa8b76b0d4fbcf2a999c

RIAK_VERSION := 3.0.7
RIAK_VERSION_HASH := 6b061612f538e2f40f58d762c1ce62ec68ea9f3a

.PHONY: $(SERVICE_NAME) push submodules repos
$(SERVICE_NAME): .state

-include $(UTILS_PATH)/make_lib/utils_repo.mk

COMMIT := $(shell git rev-parse HEAD)
TAG := $(COMMIT)
rev = $(shell git rev-parse --abbrev-ref HEAD)
BRANCH := $(shell \
if [[ "${rev}" != "HEAD" ]]; then \
	echo "${rev}" ; \
elif [ -n "${BRANCH_NAME}" ]; then \
	echo "${BRANCH_NAME}"; \
else \
	echo `git name-rev --name-only HEAD`; \
fi)

SUBMODULES = $(UTILS_PATH)
SUBTARGETS = $(patsubst %,%/.git,$(SUBMODULES))
REPOS = portage overlays/rbkmoney

$(SUBTARGETS):
	$(eval SSH_PRIVKEY := $(shell echo $(GITHUB_PRIVKEY) | sed -e 's|%|%%|g'))
	GIT_SSH_COMMAND="$(shell which ssh) -o StrictHostKeyChecking=no -o User=git `[ -n '$(SSH_PRIVKEY)' ] && echo -o IdentityFile='$(SSH_PRIVKEY)'`" \
	git submodule update --init $(subst /,,$(basename $@))
	touch $@

submodules: $(SUBTARGETS)

repos: $(REPOS)

Dockerfile: Dockerfile.sh
	REGISTRY=$(REGISTRY) ORG_NAME=$(ORG_NAME) \
	BUILD_IMAGE_TAG=$(BUILD_IMAGE_TAG) \
	COMMIT=$(COMMIT) BRANCH=$(BRANCH) \
	./Dockerfile.sh > Dockerfile

.state: Dockerfile $(REPOS)
	docker build --build-arg riak_version=$(RIAK_VERSION) \
	--build-arg riak_version_hash=$(RIAK_VERSION_HASH) \
	-t $(SERVICE_IMAGE_NAME):$(TAG) .
	echo $(TAG) > $@

test:
	$(DOCKER) run "$(SERVICE_IMAGE_NAME):$(shell cat .state)" \
	bash -c "bash --version; ip addr"

push:
	$(DOCKER) push "$(SERVICE_IMAGE_NAME):$(shell cat .state)"

clean:
	test -f .state \
	&& $(DOCKER) rmi -f "$(SERVICE_IMAGE_NAME):$(shell cat .state)" \
	&& rm .state  \
	&& rm -rf portage-root
