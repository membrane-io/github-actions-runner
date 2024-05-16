# github-actions-runners

This repo contains the tools to setup and run a docker based github action runner on our local infra.

## Getting Started

Clone this repo on the machine you wish to act as a self-hosted runner. Only works for ubuntu right now.

Go to the [self-hosted runners config](https://github.com/organizations/membrane-io/settings/actions/runners/new?arch=x64&os=linux) to get a new token

### First time setup

Initialize the runner w/ the `install.sh` script. This only needs to be ran to setup the runner for the first time (or whenever `init` is updated in the future).

```
./install.sh --scope membrane-io --token <token>
```

- `token` is the runner token provided by GitHub.
- `scope` is where the runner will listen for actions. It can be a user/org or a specific repo.

This will setup a new systemd service to run the Dockerfile in this repo. It should also create an env file
named after your scope. So if the scope is `membrane-io` there should be a file called `github-runner.membrane-io.env`.

### Start the runner

```
./start.sh --scope membrane-io
```

- `scope` is where the runner will listen for actions. It can be a user/org or a specific repo.

This script will build the local docker file and start the systemd service previously created in `install.sh`. If the service is already running it'll be restarted.

### Stop the runner

```
./shutdown.sh
```
