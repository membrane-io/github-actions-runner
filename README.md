# github-actions-runner

Tools to help operationalize self-hosting a github actions runner

## Why this exists

The big challenge with self hosting GitHub runners is that they run natively in the host and don't really clean up after themselves. An action could install (or delete) something unintentional. Scripts that don't clean up after themselves would end up leaving a mess.

GitHub provides a [base docker image](https://github.com/actions/runner/blob/main/images/Dockerfile) but not much beyond that. Thisi repo glues the rest of it together.

The self-hosted runner is run in ephemeral mode, meaning it handles one job and shuts down. The container is ran with `docker rm -f` to clean itself up after shutdown and the systemd service automatically restarts it to handle the next job.

## Getting Started

Clone this repo on the machine you wish to act as a self-hosted runner. Only works for ubuntu right now.

Go to the [self-hosted runners config](https://github.com/organizations/membrane-io/settings/actions/runners/new?arch=x64&os=linux) to get a new token (this links to Membrane's, you may need to update the URL to match your org).

### First time setup

Initialize the runner w/ the `install.sh` script. This only needs to be ran to setup the runner for the first time (or whenever `init` is updated in the future). This will setup a new systemd service to run the Dockerfile in this repo.

```
./install.sh --scope membrane-io --token <token>
```

- `token` is the runner token provided by GitHub.
- `scope` is where the runner will listen for actions. It can be a user/org or a specific repo.

### Start the runner

`start.sh` will build the local docker file and start the systemd service previously created in `install.sh`. If the service is already running it'll be restarted.

```
./start.sh --scope membrane-io
```

- `scope` is where the runner will listen for actions. It can be a user/org or a specific repo.

### Stop the runner

`stop.sh` shuts down the systemd service but doesn't (yet) do more cleanup beyond that.

```
./stop.sh --scope membrane-io
```

- `scope` the runner was configured for
