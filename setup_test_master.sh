#!/usr/bin/env bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Col[${GREEN}Error${NC}]or

# 1. 檢查 ipmitool 主程式
if ! ipmitool_path="$(command -v ipmitool)"; then
    echo -e "[${RED}Error${NC}]: ipmitool is not installed."
    exit 1
else
    # 擷取版本號 (例如: 24.0.5)
    ipmitool_ver=$(ipmitool -V 2>&1 | awk '{print $3}')
    echo -e "[${GREEN}Success${NC}]: Found ipmitool at $ipmitool_path (Version: $ipmitool_ver)"
fi

exit 0

# 1. 檢查 Docker 主程式
if ! docker_path="$(command -v docker)"; then
    echo -e "[${RED}Error${NC}]: Docker is not installed."
    exit 1
else
    # 擷取版本號 (例如: 24.0.5)
    docker_ver=$(docker version --format '{{.Server.Version}}' 2>/dev/null || docker -v | awk '{print $3}' | sed 's/,//')
    echo -e "[${GREEN}Success${NC}]: Found Docker at $docker_path (Version: $docker_ver)"
fi

# 2. 檢查 Docker Compose (V2 插件模式)
if ! docker compose version &> /dev/null; then
    echo -e "[${RED}Error${NC}]: Docker Compose is not installed or not working."
    exit 1
else
    # 擷取 Compose 版本號 (例如: v2.20.2)
    compose_ver=$(docker compose version --short)
    echo -e "[${GREEN}Success${NC}]: Found Docker Compose (Version: $compose_ver)"
fi

echo "--- 檢查完成，環境已準備就緒 ---"

./start.sh

