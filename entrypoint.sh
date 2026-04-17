#!/bin/bash

## Jenkins User
JENKINS_USER=jenkins
JENKINS_GROUP=jenkins
JENKINS_UID=1000
JENKINS_GID=1000
JENKINS_AGENT_HOME=/home/${JENKINS_USER}

if [ -z "${GIT_ACCOUNT}" ]; then
  echo "Must have to give environment variable GIT_ACCOUNT"
  exit 1
fi

# change git server
if [ -n "${GIT_SERVER}" ]; then
  sed -i -e "/git.aaa.inc/d" /etc/hosts
  echo "${GIT_SERVER} git.aaa.inc" >> /etc/hosts
fi

# setup git
if ! /root/git_setup.sh ${GIT_ACCOUNT}; then
  echo "Setup git account fail!"
  exit 1
fi

# Init Jenkins User
prepare_jenkins_user() {
  # add jenkins user
  # add jenkins group
  if getent group "${JENKINS_GID}" > /dev/null; then
      echo "Group with GID ${JENKINS_GID} already exists, skipping groupadd."
  else
      groupadd -g "${JENKINS_GID}" "${JENKINS_GROUP}"
  fi

  # 檢查 UID 1000 是否已被佔用
  EXISTING_USER=$(getent passwd "${JENKINS_UID}" | cut -d: -f1)

  if [ -n "${EXISTING_USER}" ]; then
      echo "UID ${JENKINS_UID} is already taken by user: ${EXISTING_USER}"
      # 如果佔用者不是我們要的 jenkins 使用者，可以選擇更名或直接使用
      if [ "${EXISTING_USER}" != "${JENKINS_USER}" ]; then
          echo "Renaming existing user ${EXISTING_USER} to ${JENKINS_USER}..."
          usermod -l "${JENKINS_USER}" -d "${JENKINS_AGENT_HOME}" -m "${EXISTING_USER}"
      fi
  else
      # UID 沒被佔用，正常建立
      useradd -d "${JENKINS_AGENT_HOME}" -u "${JENKINS_UID}" -g "${JENKINS_GID}" -m -s /bin/bash "${JENKINS_USER}"
  fi

  # let jenkins user can sudo
  # 注意：確保 /etc/sudoers 存在且權限正確
  echo "${JENKINS_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
}


# prepare_jenkins_user

/etc/init.d/rpcbind start
exec /usr/sbin/sshd -D