#!/bin/bash

## Customize variable
DOCKER_VERSION="ASUS_v1.25_20250915"

DOCKER_TEMPLATE_PATH="Dockerfile.template"
DOCKER_TARGET_PATH="Dockerfile"
RUN_FILE_PATH="local_runner.sh"


create_configuration_files() {

	# compose setup
	cp -f ${DOCKER_TEMPLATE_PATH} ${DOCKER_TARGET_PATH}
	sed -i -e "s|%DOCKER_VERSION%|${DOCKER_VERSION}|g" ${DOCKER_TARGET_PATH}
	sed -i -e "s|%DOCKER_VERSION%|${DOCKER_VERSION}|g" ${RUN_FILE_PATH}
}

start_build_image() {
  if ! docker build . -t tomato:${DOCKER_VERSION} -f Dockerfile; then
		echo "[Error]: Failed to build container"
		exit 1
	fi
}
# if ! docker build . -t tomato:ASUS_v1.23_20250217_v2 -f Dockerfile; then

main() {
	## Main
	create_configuration_files
	start_build_image
}

main