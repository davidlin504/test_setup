#!/usr/bin/env bash

## Customize variable
GIT_ACCOUNT="`git config user.name`"
IMAGE_TAG="latest"
KEY_TYPE="rsa"
HOST_PORT="2222"
CONTAINER_CMDS=""
DOCKER_COMPOSE_TEMPLATE_PATH="setup.template.yml"
DOCKER_COMPOSE_TARGET_PATH="setup.yml"
DOCKER_COMPOSE="docker-compose -f ${DOCKER_COMPOSE_TARGET_PATH}"

CONTAINER_IF_START_NUM=1

usage() {
  echo "Usage: $0 [-h]"
}

create_configuration_files() {
	local host_port=$1

	# compose setup
	cp -f ${DOCKER_COMPOSE_TEMPLATE_PATH} ${DOCKER_COMPOSE_TARGET_PATH}
	sed -i -e "s|%HOST_PORT%|${host_port}|g" ${DOCKER_COMPOSE_TARGET_PATH}
	sed -i -e "s|%GIT_ACCOUNT%|${GIT_ACCOUNT}|g" ${DOCKER_COMPOSE_TARGET_PATH}
	sed -i -e "s|%KEY_TYPE%|${KEY_TYPE}|g" ${DOCKER_COMPOSE_TARGET_PATH}
	sed -i -e "s|%IMAGE_TAG%|${IMAGE_TAG}|g" ${DOCKER_COMPOSE_TARGET_PATH}
}

remove_or_stop_container() {
	if [ "$FORCE_REMOVE" -eq 1 ]; then
		${DOCKER_COMPOSE} kill
		${DOCKER_COMPOSE} rm -f
	else
		${DOCKER_COMPOSE} stop > /dev/null
	fi
}

start_container() {
	## Start Container
	if ! ${DOCKER_COMPOSE} up -d; then
		echo "[Error]: Failed to start container"
		exit 1
	fi
	CONTAINERNAME="`${DOCKER_COMPOSE} ps | tail -n 1 | awk '{print $1}'`"
}

wait_container_env() {
	(
		${DOCKER_COMPOSE} logs
	)&
	local child_pid=$!

	## Wait container update
	while ! docker logs ${CONTAINERNAME} 2>&1 | tail -n 2 | grep -E "Starting (rpcbind daemon|RPC port mapper daemon rpcbind)" ; do
		sleep 5
	done
	kill ${child_pid}
}

show_interface_info() {
	echo ""
	echo -e -n "\e[0;33m[Password]: password123\e[0;0m"
	echo ""

	if [ ! -z "${CONTAINER_CMDS}" ]; then
		ssh -p ${HOST_PORT} localhost "${CONTAINER_CMDS}; ifconfig"
		echo "[Exec]: ${CONTAINER_CMDS}"
	else
		ssh -p ${HOST_PORT} localhost ifconfig
	fi

	echo -e -n "====== You can login your container by \e[0;33m[ ssh root@localhost -p $HOST_PORT ]\e[0;0m ======"
}

prepare_args() {
	echo -e -n "\e[0;33mPlease enter required arguments:"
	echo -e -n '\e[0;0m'
	echo ""

	read -e -i 1 -p "Do you want to update test_master image which would remove old test_master containers? (0/1): " FORCE_REMOVE
	# TODO after add control tag restore this
	# read -e -i ${IMAGE_TAG} -p "Which docker image tag do you want to use? (18.04/14.04/latest(==18.04)): " IMAGE_TAG

	read -e -i ${HOST_PORT} -p "Which host port do you want to bind to container ssh service?: " HOST_PORT
	read -e -i ${GIT_ACCOUNT} -p "Which git account you used to clone project git server?: " GIT_ACCOUNT
	read -e -i ${KEY_TYPE} -p "Which type of ssh key you want to copy to container? (rsa/ed25519/...): " KEY_TYPE
}

check_pubkey () {
  local pubkey="${HOME}/.ssh/id_rsa.pub"

  if [[ ! -f "$pubkey" ]]; then
    echo "正在為您生成新的 SSH Key..."
    ssh-keygen -t rsa -b 4096 -f "${HOME}/.ssh/id_rsa" -N ""
  fi

  cp ${HOME}/.ssh/id_rsa ./id_rsa.pub
  echo "公鑰已就緒：$(cat "$pubkey")"
}

main() {
	## Main
	# check_pubkey
	prepare_args
	# create_configuration_files ${HOST_PORT}
	# remove_or_stop_container
	# start_container
	# wait_container_env
	# show_interface_info
}

echo ""
echo -e -n "\e[0;32m ======== [Start create test master wizzard] ========"
echo ""
echo -e -n '\e[0;0m'
echo ""

## Get opt
FORCE_REMOVE=0
while getopts "nfi:c:th" opt; do
  case "${opt}" in
    h)
      usage
      exit 0
      ;;
    *)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done

main
