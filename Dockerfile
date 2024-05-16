FROM ghcr.io/actions/actions-runner:latest
RUN curl -fsSL --create-dirs -o $HOME/bin/yarn \
  https://github.com/yarnpkg/yarn/releases/download/v1.22.19/yarn-1.22.19.js \
  chmod +x $HOME/bin/yarn
RUN sudo apt update -y && sudo apt install build-essential git curl yarn -y