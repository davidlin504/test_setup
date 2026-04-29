#!/bin/bash

RUNNER_VERSION="16.0.0"
GITLAB_TAG="stanley-bot"

SERVICE_HOSTNAME="gitlabvm.asusautomation.com"
REGISTRATION_TOKEN="LNDaekUf97Rz6QzLUBdL"

# PXE settings
SERVICE_HOSTNAME_PXE="gitlabvm.qt.org"
REGISTRATION_TOKEN_PXE="HLRhvzA77ZXWKDrcHNz2"


# 色彩定義
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
RED='\e[0;31m'
NC='\e[0m' # No Color

STATUS_SUCCESS=[${GREEN}Success${NC}]
STATUS_WARNING=[${YELLOW}Warning${NC}]
STATUS_ERROR=[${RED}Error${NC}]

menu() {
  echo ""
  echo -e "${GREEN} ======== [Start setup gitlab runner wizzard] ======== ${NC}"
  echo ""

  echo -e "${YELLOW}Please select the action you wish to take:${NC}"
  options=("install gitlab runner" "register gitlab runner" "unregister gitlab runner")

  select opt in "${options[@]}"; do
    case $opt in
      "install gitlab runner")
        install_gitlab_runner
        break
        ;;
      "register gitlab runner")
        set_env
        prepare_args
        check_insecure_registries
        register_runner
        break
        ;;
      "unregister gitlab runner")
        unregister_runner
        break
        ;;
      *) echo "Invalid option $REPLY";;
    esac
  done
}

unregister_runner() {
  echo -e "${YELLOW}Start unregister gitlab runner:${NC}"
  # 使用 type 或 command 檢查，並整合錯誤訊息
  type gitlab-runner &>/dev/null || { echo -e "${RED}錯誤：gitlab-runner 尚未安裝${NC}"; exit 1; }

  sudo gitlab-runner unregister --all-runners
  sudo gitlab-runner verify --delete

  exit $?
}

set_env() {
  echo -e "${YELLOW}Please select the deployment location:${NC}"
  options=("Automation" "PXE")

  select opt in "${options[@]}"; do
    case $opt in
      "Automation")
        SERVICE_HOSTNAME=$SERVICE_HOSTNAME
        REGISTRATION_TOKEN=$REGISTRATION_TOKEN
        break
        ;;
      "PXE")
        SERVICE_HOSTNAME=$SERVICE_HOSTNAME_PXE
        REGISTRATION_TOKEN=$REGISTRATION_TOKEN_PXE
        break
        ;;
      *) echo "Invalid option $REPLY";;
    esac
  done
  GITLAB_URL="https://${SERVICE_HOSTNAME}/"
  CERT_FILE="${SERVICE_HOSTNAME}.crt"
  echo "Selected $opt"
  echo -e "$STATUS_SUCCESS The environmental variable has changed to $SERVICE_HOSTNAME"
  echo -e "$STATUS_SUCCESS The environmental variable has changed to $GITLAB_URL"
  echo -e "$STATUS_SUCCESS Your cert file is $CERT_FILE"
  echo ""
  sudo chmod 755 ./check_network.sh
  ENTRY=$SERVICE_HOSTNAME ./check_network.sh
}

prepare_args() {
  echo -e "${YELLOW}Please enter required arguments:${NC}"
  read -e -i ${GITLAB_TAG} -p "What is your runner tag?: " GITLAB_TAG
  read -e -i ${REGISTRATION_TOKEN} -p "What is your ruuner token?: " REGISTRATION_TOKEN

  REGISTRATION_TOKEN=$(echo "$REGISTRATION_TOKEN" | xargs)
  if [[ -z "$GITLAB_TAG" ]]; then
    echo -e "${RED}Error: GITLAB_TAG cannot be empty!${NC}"
    exit 1
  fi
  if [[ -z "$REGISTRATION_TOKEN" ]]; then
    echo -e "${RED}Error: Token cannot be empty!${NC}"
    exit 1
  fi

}

extract_domain() {
    local input=$1
    # 移除傳入網址的通訊協定部分
    local domain=$(echo "$input" | sed -e 's|^[^/]*//||' -e 's|/.*$||' | cut -d':' -f1)
    echo "$domain"
}

check_gitlab_reachability() {
    local TARGET_URL=$1
    SERVICE_HOSTNAME=$(extract_domain "$TARGET_URL")
    echo -e "${YELLOW}正在檢查服務連線 ($SERVICE_HOSTNAME)...${NC}"
    # -c 3: 傳送 3 個封包
    # -W 2: 等待回應的逾時時間為 2 秒 (避免沒回應時等太久)
    # > /dev/null 2>&1: 將標準輸出與錯誤訊息隱藏，不干擾畫面
    if ping -c 3 -W 2 "$SERVICE_HOSTNAME" > /dev/null 2>&1; then
        echo -e "${GREEN}成功：伺服器 $SERVICE_HOSTNAME 在線中。${NC}"
    else
        echo -e "${RED}錯誤：無法連線至 $SERVICE_HOSTNAME，請檢查網路或服務狀態。${NC}"
        # 視需求決定是否退出腳本
        exit 1
    fi
}

install_gitlab_runner() {

  command -v gitlab-runner &> /dev/null && {
    _path=$(command -v gitlab-runner)
    _version=$(gitlab-runner -v | grep "Version:" | cut -d ':' -f 2 | xargs)
    echo -e "[${GREEN}Success${NC}]: Found gitlab-runner at $_path (Version: $_version)"
    return 0
  }

  echo "--- 開始安裝 GitLab Runner $RUNNER_VERSION ---"
  # 1. 新增 Repo 並安裝指定版本
  curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
  # 檢查版本是否存在於 apt 倉庫
  VERSION_EXISTS=$(apt-cache madison gitlab-runner | grep "$RUNNER_VERSION")

  if [ -n "$VERSION_EXISTS" ]; then
      echo "Installing specified version: $RUNNER_VERSION"
      sudo apt-get install gitlab-runner="$RUNNER_VERSION" -y
  else
      echo -e "\e[0;31mSpecified version $RUNNER_VERSION not found or too old.\e[0m"
      echo "Installing default latest version..."
      sudo apt-get install gitlab-runner -y
  fi

  if [! command -v gitlab-runner &> /dev/null]; then
      echo "錯誤：gitlab-runner 安裝失敗，請檢查網路或軟體源設定。"
      exit 1
  fi

  echo "--- 安裝完成 ---"
}

register_runner() {
  echo -e "${YELLOW}Start register gitlab runner:${NC}"
  # 2. 設定免密碼 sudo (建議用 sudoers.d)
  echo "gitlab-runner ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/gitlab-runner

  # 3. 抓取 SSL 憑證並更新
  openssl s_client -showcerts -servername $SERVICE_HOSTNAME -connect $SERVICE_HOSTNAME:443 </dev/null 2>/dev/null | openssl x509 -outform PEM > $CERT_FILE
  sudo cp $CERT_FILE /usr/local/share/ca-certificates/
  sudo update-ca-certificates

  # 5. Git 全域設定
  sudo git config --system http.sslVerify false

  # 6. 非互動式註冊 Runner (優化重點)
  sudo gitlab-runner register \
    --non-interactive \
    --url "$GITLAB_URL" \
    --registration-token "$REGISTRATION_TOKEN" \
    --executor "shell" \
    --description "Auto-configured Runner" \
    --tag-list "$GITLAB_TAG" \
    --run-untagged="true" \
    --locked="false"

  # 7. 重啟服務
  sudo gitlab-runner restart

  echo "--- 註冊完成 ---"
}

check_insecure_registries() {
  sudo apt install jq -y
  CONF="/etc/docker/daemon.json"
  ENTRY=$SERVICE_HOSTNAME

  sudo mkdir -p /etc/docker

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
