FROM ghcr.io/actions/actions-runner:latest
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
RUN sudo apt update -y && sudo apt install build-essential git curl yarn -y