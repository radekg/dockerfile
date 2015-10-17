# dockerfile

To use, download the file, put in your path, you're ready!  
Create a .dockerfile in the directory where your Dockerfile exists.  
The content of the file should be the following:

    DOCKER_REGISTRY=your.private.registry.address
    IMAGE_NAME=image-name-for-docker-build
    IMAGE_VERSION=docker-image-version

For example:

    DOCKER_REGISTRY=docker-registry.example.com
    IMAGE_NAME=node
    IMAGE_VERSION=latest

All dockerfile command should be executed in the directory where .dockerfile and Dockerfile files are located.

# Why?

I'm fed up with creating shell scripts to manage docker images and push them to the private registry. I needed a descriptive method for defining the registry, image name and tag. Here it is.

## dockerfile build

Build a docker image.

The program will try to establish what kind of project are you running and execute or prompt to execute all the steps necessary to build the project.  
For example, if there's a pom.xml file, the program will trat the repository as a Maven project.  
In such case all the necessary mvn clean and mvn clean package will be executed for you.  
After a successful build and package step, a docker image will be built using the Docker file supplied.

You can specify custom actons for your build.

## dockerfile run (privileged)

Start a container from an image. The container will be started in an interactive mode - using `-ti` options.

## dockerfile docker-push

Upload the image to the docker repository.

## dockerfile docker-push-clean

Upload the image to the docker repository but execute clean and build first.

##dockerfile clean

Stop and remove any existing containers, remove an image and execute any clean on an underlaying project type.  
For example, if the detected project type is a Maven project, an mvn clean will be executed.  
You can override the project specific actions by providing a Dockerfile-clean.sh placed right next to this program.