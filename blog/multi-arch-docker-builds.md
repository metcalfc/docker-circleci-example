title: Build Multiple OS Architecture Docker Images
html_title: Build Multiple OS Architecture Docker Images | CircleCI
description: >-
  Learn how to build Docker images for multiple operating systems architectures from your CI/CD pipelines.
summary: >-
    Learn how to build Docker images for multiple operating systems architectures from your CI/CD pipelines.
image: /blog/media/Tutorial-Beginner-RP.jpg
author: angel-rivera
tags:
  - tutorials
  - engineering
  - security
  - devops
  - development
  - docker
---

Often there are circumstances where our software must be compiled and packaged into artifacts that must function on multiple [Operating System (OS)][1] and [processor architectures.][2] It is almost impossible to execute an application on a different OS/architecture platform, and it is a common practice to build releases for many different platforms. This can be difficult to accomplish when the platform you are using to build artifacts is different from the platform you want to target for deployment. For instance, developing an application on Windows and deploying it to a Linux or a macOS machine would involve provisioning and configuring build machines for each of the operating systems and architecture platforms you're targeting. There are also other considerations to address such as difficulty in testing and distribution.

Building artifacts that target specific platforms, is a process that requires varied integrations into respective technologies along with well defined build processes which is critical in CI/CD pipeline jobs. Multi-Architecture builds within pipelines can be achieved using various techniques but due to the stringent characteristics of processor architectures, artifacts must be produced on hardware that the artifact is compiled on and targeting.

[Docker][3] is a modern way to package applications into immutable and easily deployable artifacts in the form of [Docker images][4] and [containers][5]. As with traditional artifact packaging, Docker images are under the same processor architecture build constraints. Docker images must be build on the hardware architectures they're intended to run on. In this post I'll discuss how build Docker Images within CI/CD pipelines that target multiple processor architectures such as linux/amd64, linux/arm64, linux/riscv64 etc.

## The Repo

Let's take a look at a great [example code repository][6], built by Chad Metcalf, that demonstrates how to package an application into multiple architecture Docker images. This repo has many moving parts and concepts but I'm going to focus on the CI/CD aspects of building these multi-architecture Docker images. The CircleCI config.yml defines the CI/CD pipeline build instructions which can be found in the `.circleci/config.yml` directory. In this post I'm going to primarily focus on the `.circleci/config.yml` and `MakeFile` file that exist in this repo.

[Makefiles][7] can be viewed as build compile directives that are required by the [make utility][8] which automates build processes. The `Makefile` in this project contains the directives & commands that are executed from the CI/CD pipeline. You can define the execution commands found in the `Makefile`, into the `config.yml` file as the usual expected YAML syntax, but it's always good to learn alternative methods of building applications so I'll move forward explaining the key elements in the `Makefile` and how they're integrated into the config.yml configuration file.

## Docker BuildX

Before I go deeper into the Makefile and config.yml file tear downs, I'm going to take a moment to discuss a new Docker build feature named [BuildX][9] which is a currently a CLI plugin that extends the docker command with the full support of the features provided by Moby BuildKit builder toolkit. It provides the same user experience as docker build with many new features like creating scoped builder instances and building against multiple nodes concurrently.

At the time of this writing this post the BuildX feature is still in the **experimental** status and requires a few environment configurations on the machine where Docker images will be built. The following are BuildX install directions for Docker version **19.03** and higher. The complete [BuildX installation instructions can be found here][10] and below are the TLDR instruction for a linux machine with Docker 19.03 installed. The following commands compiles and builds the `BuildX` binary from source and installs it into the docker plugin directory:

```
export DOCKER_BUILDKIT=1
docker build --platform=local -o . git://github.com/docker/buildx
mkdir -p ~/.docker/cli-plugins
mv buildx ~/.docker/cli-plugins/docker-buildx
```

You can also download the [latest BuildX binaries for your OS here][11] and install it [using these BuildX release binary directions][12].

After installing BuildX on your Docker builder machine you can now take advantage of all the BuildX capabilities such as:

- [Multiple builder instance support][13]
- [Multi-node builds for cross-platform images][14]
- [Compose build support][15]

I'm not going to do a deep dive of BuildX in this post and I suggest you take the time to get better familiar with this feature since it is an essential technology when building Multi-Arch Docker images and heavily used in this post's examples.

## The CI/CD Pipeline config.yml file

The config.yml file in the example project leverages the `Makefile` and it's functionality to execute the appropriate commands to complete the Multi-Arch builds. This config.yml demonstrates how to leverage a single job & workflow build using a [machine executor][16] which may seem a bit out of normal since CircleCI does provide the ability to build Docker Images using the [Docker executor][17]. 

The Docker platform leverages [sharing and managing it's host operating system kernels][19] vs the [kernel emulation found in Virtual Machines][18] and since Docker containers running share the host OS kernel the are architecturally very different from Virtual Machines (VM). Virtual Machines are not based on container technology. They are made up of user spaces and kernel spaces of an operating system. VM server hardware is virtualized and each VM has it's own isolated Operating system (OS) & apps. It shares hardware resource from the host and can emulate various Processor architectures/kernels within the Virtual Machine. The kernel and hardware emulation capabilities of VMs are the main reasons the `machine executor` is the best choice for building Multi-Arch Docker images over the Docker executor.

Let's take look at the `config.yml` in the example project below:

```
version: 2.1
jobs:
  build:
    machine:
      image: ubuntu-1604:202007-01
    environment:
      DOCKER_BUILDKIT: 1
      BUILDX_PLATFORMS: linux/amd64,linux/arm64,linux/ppc64le,linux/s390x,linux/386,linux/arm/v7,linux/arm/v6
    steps:
      - checkout
      - run:
          name: Unit Tests
          command: make test
      - run:
          name: Log in to docker hub
          command: |
            docker login -u $DOCKER_USER -p $DOCKER_PASS
      - run:
          name: Build from dockerfile
          command: |
            TAG=edge make build
      - run:
          name: Push to docker hub
          command: |
            TAG=edge make push
      - run:
          name: Compose Up
          command: |
            TAG=edge make run
      - run:
          name: Check running containers
          command: |
            docker ps -a
      - run:
          name: Check logs
          command: |
            TAG=edge make logs
      - run:
          name: Compose down
          command: |
            TAG=edge make down
      - run:
          name: Install buildx
          command: |
            BUILDX_BINARY_URL="https://github.com/docker/buildx/releases/download/v0.4.2/buildx-v0.4.2.linux-amd64"

            curl --output docker-buildx \
              --silent --show-error --location --fail --retry 3 \
              "$BUILDX_BINARY_URL"

            mkdir -p ~/.docker/cli-plugins

            mv docker-buildx ~/.docker/cli-plugins/
            chmod a+x ~/.docker/cli-plugins/docker-buildx

            docker buildx install
            # Run binfmt
            docker run --rm --privileged tonistiigi/binfmt:latest --install "$BUILDX_PLATFORMS"
      - run:
          name: Tag golden
          command: |
            BUILDX_PLATFORMS="$BUILDX_PLATFORMS" make cross-build
```

As you may have noticed most of the `command:` keys in this config file execute the functions defined in the `Makefile`. This pattern produces much less YAML syntax in the config file but does obfuscate what's actually being executed in the `Makefile` which is Ok but I just wanted to call it out. next I'm going to focus on explaining some of the critical `command:` keys in this config file.

```
version: 2.1
jobs:
  build:
    machine:
      image: ubuntu-1604:202007-01
    environment:
      DOCKER_BUILDKIT: 1
      BUILDX_PLATFORMS: linux/amd64,linux/arm64,linux/ppc64le,linux/s390x,linux/386,linux/arm/v7,linux/arm/v6
    steps:
      - checkout
      - run:
          name: Unit Tests
          command: make test
      - run:
          name: Log in to docker hub
          command: |
            docker login -u $DOCKER_USER -p $DOCKER_PASS
      - run:
          name: Build from dockerfile
          command: |
            TAG=edge make build
      - run:
          name: Push to docker hub
          command: |
            TAG=edge make push
```

In the above code, the build is using a `machine executor` and assigning values to the `DOCKER_BUILDKIT` variable that enables Docker access to the experimental features and BuildX. The `BUILDX_PLATFORMS` variable is the list of OS and Processor Architectures that will produce Docker Images for each platform listed. This list is targeting the Linux OS and a variety of processor architectures.

The remaining `run:` and `command:` keys in the above example demonstrate how to execute the application's unit tests, authenticate to Docker Hub in order to pull and push images, build a Docker image using the `Dockerfile` found in the  `/app` directory and then finally pushing that image to Docker Hub.  There really isn't anything too foreign going on in these elements so let's look at some of the more exciting portions of this config file.

```
      - run:
          name: Install buildx
          command: |
            BUILDX_BINARY_URL="https://github.com/docker/buildx/releases/download/v0.4.2/buildx-v0.4.2.linux-amd64"

            curl --output docker-buildx \
              --silent --show-error --location --fail --retry 3 \
              "$BUILDX_BINARY_URL"

            mkdir -p ~/.docker/cli-plugins

            mv docker-buildx ~/.docker/cli-plugins/
            chmod a+x ~/.docker/cli-plugins/docker-buildx

            docker buildx install
            # Run binfmt
            docker run --rm --privileged tonistiigi/binfmt:latest --install "$BUILDX_PLATFORMS"
```            

In the code snippet above, the BuildX feature is being utilized to install the BuildX binary and configure it for usage in the executor. The BuildX tool can build Multi-platform images using a variety of strategies but the easiest method is to use [Qemu emulation][20] which is a generic and open source machine emulator and virtualizer. When BuildKit needs to run a binary for a different architecture it will automatically load it through a binary registered in the binfmt_misc handler. For QEMU binaries registered with binfmt_misc on the host OS to work transparently inside containers they must be registed with the fix_binary flag.

The `docker run --rm --privileged tonistiigi/binfmt:latest --install "$BUILDX_PLATFORMS"` pulls and spawns a [binfmt][22] container for every platform listed in the `$BUILD_PLATFORMS` variable defined earlier in the file.

```
      - run:
          name: Tag golden
          command: |
            BUILDX_PLATFORMS="$BUILDX_PLATFORMS" make cross-build
```

The above code snippet specifies the last command to execute in the pipeline which also builds the multi-platform Docker images that ti's targeting. The `command:` key is making a call the the `cross-build` function define inside the `Makefile` so let's take a look at the underlying commands associated with this function in the `Makefile`

```
# Makefile cross-build function

.PHONY: cross-build
cross-build:
	@docker buildx create --name mybuilder --use
	@docker buildx build --platform ${BUILDX_PLATFORMS} -t ${PROD_IMAGE} --push ./app
```

The code snippet above is the actual `cross-build` make command which creates new BuildX builder instance and follows with the `docker buildx build` command that triggers the process to build an individual Docker image for every platform listed in the `${BUILDX_PLATFORMS}` environment variable which is fed into the `--platform` flag. The `-t`flag tags/names the Docker Images and the `--push` flag will automatically push the build result to a Docker registry and in this case is Docker Hub.

## Summary

This post demonstrated how to build various Docker Images for multiple operating systems and processor architectures from within a CI/CD pipeline. This post also briefly introduced the [Docker BuildX feature][9] which is currently an experimental utility that is expected to become the defacto build utility in future releases of Docker. I consider BuildX to be the next gen Docker image building tool that will enable expansive, advanced and optimized capabilities that will enhance the current image building experience.

I also briefly discussed some of the intricacies of building Docker images targeting multiple operating systems and platform architectures which highlight the technical differences between Docker Containers and Virtual Machine concepts. Though seemly similar at an abstract view they are fundamentally different at their cores. 

Thank you for following this post and I hope you found it useful. Please feel free to reach out with feedback on Twitter [@punkdata][24].

[1]: https://en.wikipedia.org/wiki/Operating_system
[2]: https://en.wikipedia.org/wiki/Microarchitecture
[3]: https://www.docker.com/
[4]: https://docs.docker.com/engine/reference/commandline/images/
[5]: https://www.docker.com/resources/what-container
[6]: https://github.com/metcalfc/docker-circleci-example
[7]: https://www.gnu.org/prep/standards/html_node/Makefile-Basics.html#Makefile-Basics
[8]: https://www.gnu.org/software/make/
[9]: https://docs.docker.com/buildx/working-with-buildx/
[10]: https://github.com/docker/buildx#installing
[11]: https://github.com/docker/buildx/releases
[12]: https://github.com/docker/buildx#binary-release
[13]: https://github.com/docker/buildx#working-with-builder-instances
[14]: https://github.com/docker/buildx#building-multi-platform-images
[15]: https://github.com/docker/buildx#high-level-build-options
[16]: https://circleci.com/docs/2.0/executor-types/#using-machine
[17]: https://circleci.com/docs/2.0/executor-types/#using-docker
[18]: https://en.wikipedia.org/wiki/Kernel-based_Virtual_Machine
[19]: https://docs.docker.com/get-started/overview/
[20]: https://wiki.qemu.org/Main_Page
[22]: https://github.com/tonistiigi/binfmt#installing-emulators
