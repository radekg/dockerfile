#!/usr/bin/env bash

## dockerfile utility
## ----------------------------------------------------------
## To use, download the file, put in your path, you're ready!
## ----------------------------------------------------------

if [ -f `pwd`/.dockerfile ]; then
    source `pwd`/.dockerfile
fi

export DOCKERFILE_DEFAULT_IMAGE=${DOCKERFILE_DEFAULT_IMAGE-dockerfile-default-image}
export DOCKER_REGISTRY=${DOCKER_REGISTRY-""}
export IMAGE_NAME=${IMAGE_NAME-"$DOCKERFILE_DEFAULT_IMAGE"}
export IMAGE_VERSION=${IMAGE_VERSION-"latest"}
export MOUNT_WORKDIR_AS=${MOUNT_WORKDIR_AS-/dockerfile}

_base=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

command() {
  echo
  echo -e " \033[4;32mExecuting $1:\033[0m"
}

step() {
  echo
  echo -e "   \033[4;32m->\033[0m $1"
}

line() {
  echo -e "      $1"
}

error() {
  echo
  echo -e "\033[1;4;31mOuch! There was a problem...\033[0m"
  echo -e "\033[1;31m$1\033[0m"
  echo
  exit 1
}

warn() {
  echo
  echo -e "   \033[4;33m $1\033[0m"
}

clean_containers() {
  _image_pattern=$IMAGE_NAME
  if [ -n "$DOCKER_REGISTRY" ]; then
    _image_pattern="$DOCKER_REGISTRY/${_image_pattern}"
  fi
  _count=$(docker ps -a | grep "${_image_pattern}.*$IMAGE_VERSION" | wc -l)
  docker stop $(docker ps -a | grep "${_image_pattern}.*$IMAGE_VERSION" | awk '{print $1}') 2>/dev/null
  docker rm $(docker ps -a | grep "${_image_pattern}.*$IMAGE_VERSION" | awk '{print $1}') 2>/dev/null
  echo $_count
}

clean_images() {
  _image_pattern=$IMAGE_NAME
  if [ -n "$DOCKER_REGISTRY" ]; then
    _image_pattern="$DOCKER_REGISTRY/${_image_pattern}"
  fi
  _count=$(docker images | grep "${_image_pattern}.*$IMAGE_VERSION" | awk '{print $3}' | wc -l)
  docker rmi $(docker images | grep "${_image_pattern}.*$IMAGE_VERSION" | awk '{print $3}') 2>/dev/null
  echo $_count
}

if [ -z "$(docker -v 2>/dev/null)" ]; then
  error "No docker installed. Please install docker first."
fi
if [ ! -f `pwd`/Dockerfile ]; then
  error "No Dockerfile found in `pwd`. Is it a docker project?"
fi

project_type() {
  if [ -f `pwd`/pom.xml ]; then
    echo "maven"
  elif [ -f `pwd`/build.sbt ]; then
    echo "sbt"
  elif [ -f `pwd`/rebar.config ]; then
    echo "erl_rebar"
  else
    echo "unknown"
  fi
}

project_run() {
  _privileged=""
  if [ "$1" == "privileged" ]; then
    _privileged=" --privileged"
  fi
  _image_pattern=$IMAGE_NAME
  if [ -n "$DOCKER_REGISTRY" ]; then
    _image_pattern="$DOCKER_REGISTRY/${_image_pattern}"
  fi
  
  if [ $(docker images | grep "${_image_pattern}.*$IMAGE_VERSION" | wc -l) -eq 0 ]; then
    error "No image for ${_image_pattern}:$IMAGE_VERSION found. Please run \033[4mdockerfile build\033[0m."
  fi
  command "run"
  step "stopping and removing existing ${_image_pattern}:$IMAGE_VERSION containers:"
  clean_containers
  step "starting $IMAGE_NAME ${_image_pattern}:$IMAGE_VERSION:"
  if [ -n "$MOUNT_WORKDIR_AS" ]; then
    docker run ${_privileged} -ti --name $IMAGE_NAME -v `pwd`:$MOUNT_WORKDIR_AS ${_image_pattern}:$IMAGE_VERSION
  else
    docker run ${_privileged} -ti --name $IMAGE_NAME ${_image_pattern}:$IMAGE_VERSION
  fi
  line
}

# ----------------------------------------------------------------------------------------------------------------------
#   Deploy the project
# ----------------------------------------------------------------------------------------------------------------------

project_deploy() {
  command "deploy"

  if [ -z "$DOCKER_REGISTRY" ]; then
    error ".dockerfile does not declare any registry. Can't deploy."
  fi

  if [ $(docker images | grep "$DOCKER_REGISTRY/$IMAGE_NAME.*$IMAGE_VERSION" | wc -l) -eq 0 ]; then
    error "No image for $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_VERSION found. Please run \033[4mdockerfile build\033[0m."
  fi
  step "Pushing the $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_VERSION image to the registry:"
  docker push $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_VERSION
  line
}

# ----------------------------------------------------------------------------------------------------------------------
#   Build the project
# ----------------------------------------------------------------------------------------------------------------------

project_build_maven() {
  export MAVEN_OPTS='-Xmx1g -XX:MaxPermSize=256m'
  _count_deb=`ls -la $(pwd)/target/*.deb 2>/dev/null | wc -l`
  if [ $_count_deb -eq 0 ]; then
    line "I could not find a DEB package in $(pwd)/target, going to run \033[4mmvn package\033[0m..."
    line 
    mvn package || error "mvn package failed, not going to continue!"
    line 
  elif [ $_count_deb -gt 1 ]; then
    warn "I found more than one DEB package in $(pwd)/target, if this is unexpected, please execute clean first!"
  fi
  line "I am going to use $(ls -A1 $(pwd)/target/*.deb)."
  line "You can always run \033[4mclean\033[0m if this is a wrong choice..."
  line 
}

project_build_sbt() {
  warn "building sbt project not implemented yet"
}

project_build_erl_rebar() {
  warn "building erlang rebar project not implemented yet"
}

project_build() {
  command "build"
  
  _image_pattern=$IMAGE_NAME
  if [ -n "$DOCKER_REGISTRY" ]; then
    _image_pattern="$DOCKER_REGISTRY/${_image_pattern}"
  fi

  pt=$(project_type)
  if [ "$pt" != "unknown" ]; then
    step "building $pt project as $_image_pattern:$IMAGE_VERSION:"
    eval "project_build_$pt"
    docker build --no-cache --force-rm=true -t $_image_pattern:$IMAGE_VERSION .
  else
    step "building project Dockerfile only as $_image_pattern:$IMAGE_VERSION:"
    docker build --no-cache --force-rm=true -t $_image_pattern:$IMAGE_VERSION .
  fi
}

# ----------------------------------------------------------------------------------------------------------------------
#   Clean the project
# ----------------------------------------------------------------------------------------------------------------------

project_clean_erl_rebar() {
  step "cleaning erlang rebar project"
  if [ -f `pwd`/rebar ]; then
    `pwd`/rebar clean
  else
    if [ -z "$(which rebar)" ]; then
      error "Executing rebar clean but no rebar found.\nLooked for `pwd`/rebar and system wide. Please provide rebar."
    else
      rebar clean
    fi
  fi
}

project_clean_maven() {
  step "cleaning maven project"
  mvn clean
}

project_clean_sbt() {
  step "cleaning sbt project"
  sbt clean
}

project_clean() {
  command "clean"
  _image_pattern=$IMAGE_NAME
  if [ -n "$DOCKER_REGISTRY" ]; then
    _image_pattern="$DOCKER_REGISTRY/${_image_pattern}"
  fi
  step "stopping and removing existing ${_image_pattern}:$IMAGE_VERSION containers:"
  line "stopped and removed $(clean_containers) conatiners"
  step "removing existing ${_image_pattern}:$IMAGE_VERSION image:"
  line "removed $(clean_images) images"
  if [ -f `pwd`/Dockerfile-clean.sh ]; then
    step "executing custom provided clean script:"
    `pwd`/Dockerfile-clean.sh
  else
    pt=$(project_type)
    if [ "$pt" != "unknown" ]; then
      eval "project_clean_$pt"
    fi
  fi
  line
}

project_help() {
  step "General info"
  line "To use, download the file, put in your path, you're ready!"
  line "Create a \033[4m.dockerfile\033[0m in the directory where your \033[4mDockerfile\033[0m exists."
  line "The content of the file should be the following:"
  line
  line "  \033[4mDOCKER_REGISTRY=your.private.registry.address\033[0m"
  line "  \033[4mIMAGE_NAME=image-name-for-docker-build\033[0m"
  line "  \033[4mIMAGE_VERSION=docker-image-version\033[0m"
  line
  line "For example:"
  line
  line "  \033[4mDOCKER_REGISTRY=docker-registry.example.com\033[0m"
  line "  \033[4mIMAGE_NAME=node\033[0m"
  line "  \033[4mIMAGE_VERSION=latest\033[0m"
  line
  line "All dockerfile command should be executed in the directory where \033[4m.dockerfile\033[0m and \033[4mDockerfile\033[0m files are located."
  step "dockerfile help"
  line "Display this screen."
  step "dockerfile build"
  line "Build a docker image."
  line "The program will try to establish what kind of project are you running and execute"
  line "or prompt to execute all the steps necessary to build the project."
  line "For example, if there's a pom.xml file, the program will trat the repository as a Maven project."
  line "In such case all the necessary \033[4mmvn clean\033[0m and \033[4mmvn clean package\033[0m will be executed for you."
  line "After a successful build and package step, a docker image will be built using the Docker file supplied."
  line
  line "You can specify custom actons for your build. If you create a "
  step "dockerfile run (privileged)"
  line "Start a container from an image. The container will be started in an interactive mode - using \033[4m-ti\033[0m options."
  step "dockerfile docker-push"
  line "Upload the image to the docker repository."
  step "dockerfile docker-push-clean"
  line "Upload the image to the docker repository but execute clean and build first."
  step "dockerfile clean"
  line "Stop and remove any existing containers, remove an image and execute any clean on an underlaying project type."
  line "For example, if the detected project type is a Maven project, an \033[4mmvn clean\033[0m will be executed."
  line
  line "You can override the project specific actions by providing a \033[4mDockerfile-clean.sh\033[0m placed right "
  line "next to this program."
  line
}

case "$1" in
  build )
    project_build
  ;;
  rebuild )
    project_clean  
    project_build
  ;;
  run )
    project_run $2
  ;;
  docker-push )
    project_deploy
  ;;
  docker-push-clean )
    project_clean
    project_build
    project_deploy
  ;;
  clean )
    project_clean
  ;;
  help )
    project_help
  ;;
  * )
    project_help
  ;;
esac