FROM ghcr.io/actions/actions-runner:latest
RUN curl -fsSL --create-dirs -o $HOME/bin/yarn \
  https://github.com/yarnpkg/yarn/releases/download/v1.22.19/yarn-1.22.19.js \
  chmod +x $HOME/bin/yarn
RUN sudo apt update -y && sudo apt install build-essential git curl yarn -y

# Runner is configured as ephemeral such that the process ends when the job is done
# This allows the service to clean up the docker container
CMD [ "./config.sh --name $RUNNER_NAME --url $RUNNER_URL --token $RUNNER_TOKEN --labels ${RUNNER_LABELS:-\"self-hosted\"} --unattended --ephemeral && ./run.sh"]