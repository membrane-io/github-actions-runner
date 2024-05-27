FROM ghcr.io/actions/actions-runner:latest
RUN sudo apt update -y && sudo apt install build-essential git curl unzip wget openssl libssl-dev pkg-config golang zip -y
# Required by GitHub Actions
RUN wget https://github.com/PowerShell/PowerShell/releases/download/v7.4.2/powershell_7.4.2-1.deb_amd64.deb && \
  sudo dpkg -i powershell_7.4.2-1.deb_amd64.deb && \
  sudo apt-get install -f && \
  rm powershell_7.4.2-1.deb_amd64.deb

RUN curl -fsSL --create-dirs -o ~/bin/yarn \
  https://github.com/yarnpkg/yarn/releases/download/v1.22.19/yarn-1.22.19.js && \
  chmod +x ~/bin/yarn

COPY .runner_exec.sh exec.sh
RUN sudo chmod +x exec.sh

CMD [ "./exec.sh"]