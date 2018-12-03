##############################################################
#
# Global variables
#
# Directory that contains the Redsocks source code
REDSOCKS_SRC := 
# Tag to use for the Docker image
IMAGE_TAG := redsocks
# HTTP proxy to use when building the docker image
HTTP_PROXY := 
#
##############################################################

current_dir := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
http_proxy=--build-arg http_proxy=$(HTTP_PROXY) --build-arg https_proxy=$(HTTP_PROXY)

.PHONY: help
help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
.DEFAULT_GOAL := help
	
build-image: ## Build the Redsocks Docker image (make build-image REDSOCKS_SRC=<Path to Redsocks source code> OR make build-image REDSOCKS_SRC=<Path to Redsocks source code> HTTP_PROXY=http://<server>:<port>)
	@if [ -z $$REDSOCKS_SRC ]; then \
		echo "Please set REDSOCKS_SRC to the directory that contains the Redsocks source code"; \
		exit 1; \
	fi

	@tar -cf - --exclude=build-context.tar.gz -C $(current_dir) rootfs -C $(REDSOCKS_SRC) . | gzip > $(current_dir)/build-context.tar.gz
	docker build -f $(current_dir)/Dockerfile -t $(IMAGE_TAG) $(http_proxy) $(current_dir)
	@rm $(current_dir)/build-context.tar.gz
	
run-image: ## Runs a previously built Docker image. Accepts parameters HTTP_PROXY_HOST and HTTP_PROXY_PORT.
	docker run --rm -it --net=host --cap-add=NET_ADMIN -e HTTP_PROXY_HOST=$(HTTP_PROXY_HOST) -e HTTP_PROXY_PORT=$(HTTP_PROXY_PORT) $(IMAGE_TAG)
	
shell: ## Runs a previously built Docker image and drops into a shell
	docker run --rm -it --net=host --cap-add=NET_ADMIN --entrypoint /bin/bash $(IMAGE_TAG)