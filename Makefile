UTILS_PATH := build-utils
SERVICE_NAME := riak-base
ORG_NAME := xpay_rbk
BUILD_IMAGE_TAG := 2dd1d2f13ef145ae5084170c50dbeb478e683474
PORTAGE_REF := e1cd9e723e70a4c457d190f0d498c6e79b9466da
OVERLAYS_XPAY_REF := 04805dc8396b6e4046726a78e9d86a8e8529a6b4

RIAK_VERSION := 3.0.9
RIAK_VERSION_HASH := ed5c0a7205c1a4ef63d479f21b77b476aaeb32a0ee425081e35d0b83bc7eb7b6

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
REPOS = portage overlays/xpay

$(SUBTARGETS):
	$(eval SSH_PRIVKEY := $(shell echo $(GITHUB_PRIVKEY) | sed -e 's|%|%%|g'))
	GIT_SSH_COMMAND="$(shell which ssh) -o StrictHostKeyChecking=no -o User=git `[ -n '$(SSH_PRIVKEY)' ] && echo -o IdentityFile='$(SSH_PRIVKEY)'`" \
	git submodule update --init $(subst /,,$(basename $@))
	touch $@

submodules: $(SUBTARGETS)

repos: $(REPOS)

Dockerfile: Dockerfile.sh Makefile
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
	bash -c "riak version; ip addr"

push:
	$(DOCKER) push "$(SERVICE_IMAGE_NAME):$(shell cat .state)"

clean:
	test -f .state \
	&& $(DOCKER) rmi -f "$(SERVICE_IMAGE_NAME):$(shell cat .state)" \
	&& rm .state  \
	&& rm -rf portage-root
