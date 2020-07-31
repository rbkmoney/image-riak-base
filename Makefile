UTILS_PATH := build-utils
SERVICE_NAME := riak-base
BUILD_IMAGE_TAG := 4ede552907405681d291e3271c7433bb9b972460
PORTAGE_REF := 3581ed8a5b4e74c3f5bc94ea9d6e89eb1f44116a
OVERLAYS_RBKMONEY_REF := 19fec3eb3f99d91b201fce3c0b5a82a88409556a

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
	docker build -t $(SERVICE_IMAGE_NAME):$(TAG) .
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
