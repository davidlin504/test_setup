#!/bin/bash

TAG="ASUS_v1.25_20250915"
USERNAME="stanely"
PASSWORD="xxx"

CI_REGISTRY="gitlabvm.asusautomation.com:5005"
INTERNAL_DOCKER_REGISTRY="gitlabvm.asusautomation.com:5005/ami-images/spx-taas"
# PXE settings
CI_REGISTRY_PXE="gitlabvm.qt.org:5005"
INTERNAL_DOCKER_REGISTRY_PXE="gitlabvm.qt.org:5005/ami-images/spx-taas"

# 色彩定義
GREEN='\e[0;32m'
BLUE='\e[0;34m'
YELLOW='\e[0;33m'
RED='\e[0;31m'
NC='\e[0m' # No Color

STATUS_SUCCESS=[${GREEN}Success${NC}]
STATUS_INFO=[${BLUE}Info${NC}]
STATUS_WARNING=[${YELLOW}Warning${NC}]
STATUS_ERROR=[${RED}Error${NC}]


menu() {
  echo ""
  echo -e "${GREEN} ======== [Start setup docker image wizzard] ======== ${NC}"
  echo ""

  echo -e "${YELLOW}Please select the action you wish to take:${NC}"
  options=("check docker login status" "login and pull spx image")

  select opt in "${options[@]}"; do
    case $opt in
      "check docker login status")
        set_env
        check_service_reachability
        check_docker_config
        break
        ;;
      "login and pull spx image")
        set_env
        check_service_reachability
        prepare_args
        check_insecure_registries
        docker_login_and_pull_image
        check_spx_image
        break
        ;;
      *) echo "Invalid option $REPLY";;
    esac
  done
}

check_service_reachability() {
  echo -e "$STATUS_INFO Current directory: $(pwd)"
  SCRIPT_PATH="./check_network.sh"

  if [ -f "$SCRIPT_PATH" ]; then
      sudo chmod 755 "$SCRIPT_PATH"
      "$SCRIPT_PATH" $CI_REGISTRY
  fi
}

set_env() {
  echo -e "${YELLOW}Please select the deployment location:${NC}"
  options=("Automation_192.168.87.x" "PXE_192.168.(0-3).x")

  select opt in "${options[@]}"; do
    case $opt in
      "Automation_192.168.87.x")
        CI_REGISTRY=$CI_REGISTRY
        INTERNAL_DOCKER_REGISTRY=$INTERNAL_DOCKER_REGISTRY
        break
        ;;
      "PXE_192.168.(0-3).x")
        CI_REGISTRY=$CI_REGISTRY_PXE
        INTERNAL_DOCKER_REGISTRY=INTERNAL_DOCKER_REGISTRY_PXE
        break
        ;;
      *) echo "Invalid option $REPLY";;
    esac
  done
  echo "Selected $opt"
  echo "prepare env ...."
  echo -e "$STATUS_SUCCESS The environmental variable has changed to $CI_REGISTRY"
  echo -e "$STATUS_SUCCESS The environmental variable has changed to $INTERNAL_DOCKER_REGISTRY"
  echo ""
}

prepare_args() {
  echo -e "${YELLOW}Please enter required arguments:${NC}"
  read -e -i ${USERNAME} -p "What is the gitlab useranme?: " USERNAME
  read -e -i ${PASSWORD} -p "What is the gitlab password?: " PASSWORD
  read -e -i ${TAG} -p "What is the spx docker image tag?: " TAG
}

docker_login_and_pull_image() {
  SPX_IMAGE=$INTERNAL_DOCKER_REGISTRY:$TAG
  docker login -u $USERNAME -p $PASSWORD $CI_REGISTRY > /dev/null 2>&1
  docker pull $SPX_IMAGE > /dev/null 2>&1
}

check_spx_image() {
  if docker image inspect "$SPX_IMAGE" > /dev/null 2>&1; then
    echo -e "$STATUS_SUCCESS ✅ 找到映像檔: $SPX_IMAGE"
    echo -e "$STATUS_SUCCESS 已成功拉取SPX映像檔"
  else
      echo -e "$STATUS_ERROR ❌ 找不到映像檔: $SPX_IMAGE"
      echo -e "$STATUS_ERROR 請確認權限或是網路是否發生問題"
      # 這裡可以加入 docker login 或 docker pull 的邏輯
  fi
}

check_docker_config() {
  # ~/.docker/config.json
  # 檢查是否已登入該網域 (檢查 config.json 中是否有該網域的 auths)
  if ! grep -q $CI_REGISTRY ~/.docker/config.json; then
    echo -e "$STATUS_INFO 需要登入 $CI_REGISTRY"
    echo -e "Usage: docker login $CI_REGISTRY -u username -p password"
  else
    echo -e "$STATUS_SUCCESS docker 已登入 $CI_REGISTRY"
  fi
}

check_insecure_registries() {

  if [! command -v jq &> /dev/null]; then
    echo -e "$STATUS_INFO 開始安裝 jq"
    sudo apt install jq -y
  fi
  CONF="/etc/docker/daemon.json"
  ENTRY=$CI_REGISTRY

  # 1. 檢查檔案是否存在，不存在則建立基本格式
  if [ ! -f "$CONF" ]; then
      echo "{\"insecure-registries\": []}" | sudo tee "$CONF" > /dev/null
  fi

  # 2. 檢查是否已經包含該網域
  if grep -q "$ENTRY" "$CONF"; then
      echo -e "$STATUS_SUCCESS $ENTRY 已存在於設定中，無需修改。"
  else
      echo -e "$STATUS_INFO 正在將 $ENTRY 加入 insecure-registries..."
      sudo jq ".[\"insecure-registries\"] += [\"$ENTRY\"] | .[\"insecure-registries\"] |= unique" "$CONF" > /tmp/docker_dm.json && sudo mv /tmp/docker_dm.json "$CONF"

      echo -e "$STATUS_INFO 重啟 Docker 服務..."
      sudo systemctl daemon-reload
      sudo systemctl restart docker
  fi
}

menu