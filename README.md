# Portainer + Caddy docker compose stack

The purpose of this stack is, to be the first stack to be deployed to a Docker server and to be the only one that is deployed and updated manually, using the command line.

Disclaimer: The entire repository and the way stacks are deployed is strongly opinionated but has worked really well for me for several years now.
I use it mainly for small services but have also used it to host dockerized game servers.

The stack consists of the Portainer application _or_ the Portainer agent, as well as a Caddy for TLS offloading.

The Caddy image, that is deployed by this stack, is configured by adding labels to the Docker compose services that are to be hosted later on.
This makes configuration really easy down the line, as this stack does not have to change at all, unless one of the images receives an update.

## Prerequisites
* One or more servers
* Docker installed and running on system startup
* At least one domain

## Server structure

When running multiple servers, Portainer will make use of its agents to manage the Docker deployments on all of them.
However, this stack is not developed with the intention for a Docker Swarm or the like.
It has solely been tested with individual Docker servers that don't know about each other, apart from Portainer managing all of them.

## Directory structure

This README and also the scripts for this stack stack assume, that all files related to the hosted Docker containers reside in sub folders of a `/docker` folder. For example:

```shell
# ls -l /docker
total 8
drwxr-xr-x 4 root root 4096 Mar 21 12:36 caddy-portainer
drwxr-xr-x 3 root root 4096 Nov 18 18:00 foo
```

The contents of the sub folders are specific to the respective stack.
Usually, this would be the place for mount points like data volumes or the like.
A stack might not require a folder here at all, if it is fully self-contained.

## Setup

### On all servers

Create the base folder:
```shell
sudo mkdir /docker
```

Clone this repo into the `/docker` folder:
```shell
pushd /docker
sudo git clone https://github.com/schroenser/caddy-portainer.git
popd
```

### On the server you want to host Portainer on

Create an `.env` file according to the `.env.template`. For example:
```shell
echo DOMAIN=docker.mydomain.dev >> /docker/caddy-portainer/.env
chown root:root /docker/caddy-portainer/.env
```

Make sure that `docker.mydomain.dev` points to the server and that ports `80` and `443` are reachable.
Otherwise, Caddy will fail to generate a Let's Encrypt certificate for the Portainer server and it won't be reachable.

Start the stack:
```shell
sudo docker compose --file /docker/caddy-portainer/compose.server-ce.yml up
```

Browse to `https://docker.mydomain.dev` and complete the Portainer setup.
_(Sadly, I don't remember what happens at this point. If memory serves correctly, you create a username and password for Portainer)_

Now you can either [deploy more agents](#adding-more-servers-using-agents) or [deploy your first stack]().

### Adding more servers using agents

Make sure that port `9001` of the agent server is reachable from your Portainer server.

Start the stack:

```shell
sudo docker compose --file /docker/caddy-portainer/compose.agent.yml up
```

In Portainer
* go to "Administration" -> "Environment-related" -> "Environments"
* click "Add environment"
* select "Docker Standalone" -> "Start Wizard"
* select "Agent", give the environment recognizable "Name" and set the "Environment URL" to point to the agent server's IP or domain, with port `9001` then "Connect"

## Deploying stacks

I have a Git repository _per stack_ on GitHub, containing the respective `compose.yml`.
I've experimented with having multiple stacks in a single repository but the webhook (see further down) will then cause Portainer to update all stacks, no matter which one changed.

### Compose

This way to deploy things affects the compose file in only two ways:

1. Files and folders for mount points reside under `/docker/<stackname>/...` on the respective server.
   I made no assumption on how they got there.
   I personally create config files by hand, if some service needs a config file mounted.
   The same goes for folders that server as mount points for data volumes.
   This rule is not strictly required, you can mount any file or folder from your host but I found that this keeps things really tidy.
   Also, as far as I know, it's forward compatible with an Enterprise Edition feature of Portainer, where it is able to add files from the Git repository to that location.
2. _If_ your service provides web or REST services and you want to leverage the TLS offloading provided by the Caddy, you need to make sure that
   1. the stack runs in the same network as the Caddy
      ```yaml
      networks:
        caddy:
          external: true
      ```
   2. you add labels to your service(s) to configure the reverse proxy
      ```yaml
      labels:
        caddy: ${DOMAIN}
        caddy.reverse_proxy: "{{upstreams 8080}}"
      ```

In the code snipped above, `${DOMAIN}` will be set as an environment variable, when deploying the stack with Portainer and `8080` is the port that the service is running on.

### Portainer

In Portainer...

1. choose the environment (server) you want to deploy your stack to.
2. go to "Stacks" and click "Add stack"
3. give the stack a "Name" and pick "Repository"
4. fill in the repository URL of the repository containing your compose file.
   Note that you might need authentication, for example when hosting your compose files in private repositories on GitHub.
   In that case, you need to activate "Authentication" and provide your "Username" and a "Personal Access Token".
   In the case of GitHub, those can be found in the [Settings -> Developer Settings -> Personal access tokens -> Tokens (classic)](https://github.com/settings/tokens).
5. Choose the branch you want to use.
   Working with branches might be useful for staged deployments (dev, test, prod), however, I have not experimented with that, yet.
6. Set the "Compose path" relative to your repository.
   For me, this is usually simply `compose.yml` but your compose file might reside in a directory.
7. Check "GitOps updates" and pick "Webhook".
8. Use the "Copy link" button to copy the webhook URL.
   _DO NOT_ copy the text left of the button, it is shortened.
   No, this has never happened to me, ever.
   Not a single time.
10. In your GitHub repository go to "Settings" -> "Webhooks" and click "Add webhook"
11. Simply paste the URL into the "Payload URL" field and click "Add webhook".
    It won't work at this time, as the Portainer stack is not yet deployed but neither GitHub nor Portainer do seem to care.
12. Click "Add an environment variable" to add environment variables required for your stack.
   This is where that `DOMAIN` environment variable from the [Compose](#compose) step comes into play, if you want to make use of Caddy's TLS offloading.
13. "Deploy the stack"

From now on, pushes to the repository will trigger an update of the stack in Portainer, via the Webhook, which in turn causes Portainer to re-fetch the `compose.yml` and update the stack accordingly.

## Updating

The image versions in this repository are updated using GitHubs Dependabot.

Whenever a new version is available, I will merge the pull request and then manually go through my servers and use
```shell
sudo /docker/caddy-portainer/update-server-ce.sh
```
or

```shell
sudo /docker/caddy-portainer/update-agent.sh
```
scripts, provided with this repository, to pull the changes via Git, have Docker pull the new images and then quickly rebuild the stack.

I guess this _could_ be automated using cron but I couldn't be bothered. ;)

Note that this _might_ cause a slight downtime on other stacks if Caddy is being updated but the Portainer and Portainer Agent updates only affect Portainer itself.
