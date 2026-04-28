#!/usr/bin/env bash

## Customize variable
GIT_ACCOUNT="`git config user.name`"
IMAGE_TAG="latest"
KEY_TYPE="rsa"
HOST_PORT="2222"
CONTAINER_CMDS=""
DOCKER_COMPOSE_TEMPLATE_PATH="test_master.template.yml"
DOCKER_COMPOSE_TARGET_PATH="test_master.yml"
DOCKER_COMPOSE="docker compose -f ${DOCKER_COMPOSE_TARGET_PATH}"
SHARE_VOLUMES_OUTPUT="${HOME}/output"
SHARE_VOLUMES_MYVOL="${HOME}/myvol"
DOCKERFILE="Dockerfile"

usage() {
  echo "Usage: $0 [-h]"
}

check_share_volumes() {
  local SHARE_VOLUMES_OUTPUT=$1
  if [ ! -d "${SHARE_VOLUMES_OUTPUT}" ]; then
    echo "Creating output directory at ${SHARE_VOLUMES_OUTPUT}..."
    mkdir -p "${SHARE_VOLUMES_OUTPUT}"
  fi
}


create_configuration_files() {
  local host_port=$1
  check_share_volumes ${SHARE_VOLUMES_OUTPUT}
  check_share_volumes ${SHARE_VOLUMES_MYVOL}
  # compose setup
  cp -f ${DOCKER_COMPOSE_TEMPLATE_PATH} ${DOCKER_COMPOSE_TARGET_PATH}
  sed -i -e "s|%HOST_PORT%|${host_port}|g" ${DOCKER_COMPOSE_TARGET_PATH}
  sed -i -e "s|%GIT_ACCOUNT%|${GIT_ACCOUNT}|g" ${DOCKER_COMPOSE_TARGET_PATH}
  sed -i -e "s|%SHARE_VOLUMES_OUTPUT%|${SHARE_VOLUMES_OUTPUT}|g" ${DOCKER_COMPOSE_TARGET_PATH}
  sed -i -e "s|%SHARE_VOLUMES_MYVOL%|${SHARE_VOLUMES_MYVOL}|g" ${DOCKER_COMPOSE_TARGET_PATH}
  sed -i -e "s|%DOCKERFILE%|${DOCKERFILE}|g" ${DOCKER_COMPOSE_TARGET_PATH}
  # sed -i -e "s|%KEY_TYPE%|${KEY_TYPE}|g" ${DOCKER_COMPOSE_TARGET_PATH}
  # sed -i -e "s|%IMAGE_TAG%|${IMAGE_TAG}|g" ${DOCKER_COMPOSE_TARGET_PATH}
}

remove_or_stop_container() {
  if [ "$FORCE_REMOVE" -eq 1 ]; then
    ${DOCKER_COMPOSE} kill
    ${DOCKER_COMPOSE} rm -f
    ${DOCKER_COMPOSE} build
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
  # 啟動背景監看日誌
  ${DOCKER_COMPOSE} logs -f &
  local child_pid=$!

  echo "Waiting for ${CONTAINERNAME} to initialize..."

  ## 改良後的等待邏輯
  while true; do
    # 1. 抓取最後 20 行增加容錯率
    # 2. 使用 -q 安靜模式，只要找到就結束
    # 3. 關鍵字過濾掉中間可能存在的特殊字元 (.*)
    if docker logs --tail 20 ${CONTAINERNAME} 2>&1 | grep -Ei "Starting.*(rpcbind|RPC port mapper)" ; then
      echo "Detection success: RPC service is up."
      break
    fi

    # 檢查容器是否還活著，避免死循環
    if ! docker ps -q --filter "name=${CONTAINERNAME}" | grep -q . ; then
       echo "Error: Container ${CONTAINERNAME} is not running."
       kill ${child_pid}
       return 1
    fi

    sleep 5
  done

  kill ${child_pid} 2>/dev/null
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
  echo ""
}

prepare_args() {
  echo -e -n "\e[0;33mPlease enter required arguments:"
  echo -e -n '\e[0;0m'
  echo ""

  read -e -i 1 -p "Do you want to update test_master image which would remove old test_master containers? (0/1): " FORCE_REMOVE
  # TODO after add control tag restore this
  # read -e -i ${IMAGE_TAG} -p "Which docker image tag do you want to use? (18.04/14.04/latest(==18.04)): " IMAGE_TAG

  # read -e -i ${HOST_PORT} -p "Which host port do you want to bind to container ssh service?: " HOST_PORT
  read -e -i ${GIT_ACCOUNT} -p "Which git account you used to clone project git server?: " GIT_ACCOUNT
  read -e -i ${KEY_TYPE} -p "Which type of ssh key you want to copy to container? (rsa/ed25519/...): " KEY_TYPE
  read -e -i ${SHARE_VOLUMES_OUTPUT} -p "Which output directory do you want to use? " SHARE_VOLUMES_OUTPUT
  read -e -i ${SHARE_VOLUMES_MYVOL} -p "Which myvol directory do you want to use? " SHARE_VOLUMES_MYVOL
  options=("Automation" "PXE")

  select opt in "${options[@]}"; do
    case $opt in
      "Automation")
        DOCKERFILE="Dockerfile"
        break
        ;;
      "PXE")
        DOCKERFILE="Dockerfile-pxe"
        break
        ;;
      *) echo "Invalid option $REPLY";;
    esac
  done
  echo "Selected $opt"
  echo "prepare env ...."
  echo "env $DOCKERFILE"
}

check_pubkey() {
  local pubkey="${HOME}/.ssh/id_${KEY_TYPE}.pub"

  if [[ ! -f "$pubkey" ]]; then
    echo "正在為您生成新的 SSH Key..."
    ssh-keygen -t ${KEY_TYPE} -b 4096 -f "${HOME}/.ssh/id_${KEY_TYPE}" -N ""
  fi

  cp ${HOME}/.ssh/id_${KEY_TYPE}.pub ./ssh_key.pub
  # echo "公鑰已就緒：$(cat "$pubkey")"
}

main() {
  prepare_args
  check_pubkey
  create_configuration_files ${HOST_PORT}
  remove_or_stop_container
  start_container
  wait_container_env
  show_interface_info
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