# Docker CircleCI Example

Welcome. This is a simple example application to show a common Docker specific
CircleCI setup. We have a Python Flask application that is built and
deployed in Docker containers using Dockerfiles and Docker Compose.

## CI Setup

We want to setup CI to test:

- ✒ Every commit to `main`
- ✉ Every PR
- 🌃 Integration tests nightly
- 🐳 Releases via tags pushed to Docker Hub.

We are going to use CircleCI for the CI infrastructure.

After CI when it comes time for production we want to use Docker's new Amazon
ECS integration to deploy from Docker Compose directly to Amazon ECS with
Fargate. So we will push our release tagged images to Docker Hub
which is integrated directly Amazon ECS [via Docker Compose.](https://github.com/metcalfc/docker-action-examples/blob/main/docker-compose.yml)

The [Dockerfile](https://github.com/metcalfc/docker-action-examples/blob/main/app/Dockerfile) is setup to use multi stage builds. We have stages for
[`test`](https://github.com/metcalfc/docker-action-examples/blob/main/app/Dockerfile#L9-L12)
and [`prod`](https://github.com/metcalfc/docker-action-examples/blob/main/app/Dockerfile#L14-L16).
This means we'll need Docker Buildx and we can use the a preview of the
new Docker Buildx Action. This is going to let us achieve a couple awesome outcomes:

- We are going to use the buildx backend by default. Buildx out of the box brings a
  number of improvements over the default `docker build`. [Here.](https://github.com/metcalfc/docker-action-examples/blob/main/.github/workflows/release.yml#L40-L42)
- We are going to setup buildx caching to take advantage of the where possible with Circle's caching (paid feature).
  You should see build performance improvements when repeating builds with common
  layers. 
- We are going to setup QEMU to do cross platform builds. In the example, we'll
  build this application for every Linux architecture that Docker Hub supports. 
  

I'm not going to implement CD for this example.
Mostly because I don't want to leave an Amazon ECS cluster running. But you can
see a demo of this in one of my past streams: https://www.youtube.com/watch?v=RfQrgZFq_P0

## Compose sample application

### Python/Flask application

Project structure:

```
.
├── docker-compose.yaml
├── app
    ├── Dockerfile
    ├── requirements.txt
    └── app.py

```

[_docker-compose.yaml_](docker-compose.yaml)

```
services:
  web:
    build: app
    ports:
      - '5000:5000'
```

## Deploy with docker-compose

```
$ docker-compose up -d
Creating network "flask_default" with the default driver
Building web
Step 1/6 : FROM python:3.7-alpine
...
...
Status: Downloaded newer image for python:3.7-alpine
Creating flask_web_1 ... done

```

## Expected result

Listing containers must show one container running and the port mapping as below:

```
$ docker ps
CONTAINER ID        IMAGE                        COMMAND                  CREATED             STATUS              PORTS                  NAMES
c126411df522        flask_web                    "python3 app.py"         About a minute ago  Up About a minute   0.0.0.0:5000->5000/tcp flask_web_1
```

After the application starts, navigate to `http://localhost:5000` in your web browser or run:

```
$ curl localhost:5000
Hello Docker and GitHub!
```

Stop and remove the containers

```
$ docker-compose down
```
