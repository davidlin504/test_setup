#!/bin/bash
docker_daemon="$(which docker)"
docker_compose_daemon="$(which docker-compose)"

echo -e -n "\e[0;31m"
echo ""
if [ -z ${docker_daemon} ]; then
	echo "[Error]: Must have to install docker"
	exit 1
fi
if [ -z ${docker_compose_daemon} ]; then
	echo "[Error]: Must have to install docker-compose. e.g. pip install docker-compose"
	exit 1
fi

echo -e -n '\e[0;0m'
echo ""


./start.sh
