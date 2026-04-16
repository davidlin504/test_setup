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

  # add jenkins user (檢查使用者是否已存在，避免重複執行報錯)
  if ! id -u "${JENKINS_USER}" > /dev/null 2>&1; then
      useradd -d "${JENKINS_AGENT_HOME}" -u "${JENKINS_UID}" -g "${JENKINS_GID}" -m -s /bin/bash "${JENKINS_USER}"
  fi

  # let jenkins user can sudo
  # 注意：確保 /etc/sudoers 存在且權限正確
  echo "${JENKINS_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
}


# prepare_jenkins_user

# /etc/init.d/rpcbind start
exec /usr/sbin/sshd -D