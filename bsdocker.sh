#!/bin/bash

# This script provides a simple interface for folks to use the docker install

coreimage=quay.io/blockstack/blockstack-core:latest
browserimage=quay.io/blockstack/blockstack-browser:latest
# Local Blockstack directory
homedir=$HOME/.blockstack
# Blockstack Directory inside container
containerdir=/root/.blockstack
# Name of Blockstack API container
corecontainer=blockstack-api
# Name of Blockstack Browser container
browsercontainer=blockstack-browser

build () {
  echo "Building blockstack docker image. This might take a minute..."
  docker build -t $coreimage .
}

setup () {
  if [ $# -eq 0 ]; then
    echo "Need to input new wallet password when running setup: ./bsdocker setup mypass"
    exit 1
  fi
  docker run -it -v $homedir:$containerdir $coreimage blockstack setup -y --password $1
  
  # Use init containers to set the API bind to 0.0.0.0
  docker run -it -v $homedir:$containerdir $coreimage sed -i 's/api_endpoint_bind = localhost/api_endpoint_bind = 0.0.0.0/' $containerdir/client.ini
  docker run -it -v $homedir:$containerdir $coreimage sed -i 's/api_endpoint_host = localhost/api_endpoint_host = 0.0.0.0/' $containerdir/client.ini
}

start () {
  # Check for args first
  if [ $# -eq 0 ]; then
    echo "Need to input password for wallet located in the $HOME/.blockstack folder when staring api: ./bsdocker start mypass"
    exit 1
  fi
  
  # Check for the blockstack-api container is running or stopped. 
  if [ "$(docker ps -q -f name=$corecontainer)" ]; then
    echo "container is already running"
    exit 1
  elif [ ! "$(docker ps -q -f name=$corecontainer)" ]; then
    if [ "$(docker ps -aq -f status=exited -f name=$corecontainer)" ]; then
      # cleanup old container if its still around
      echo "removing old container..."
      docker rm $corecontainer
    fi
    
    # If there is no existing $corecontainer container, run one
    if [[ $(uname) == 'Linux' ]]; then
      docker run -d --name $corecontainer -v $homedir:$containerdir -p 6270:6270 $coreimage blockstack api start-foreground --password $1 --api_password $1
    elif [[ $(uname) == 'Darwin' ]]; then
      docker run -d --name $corecontainer -v $homedir:$containerdir -p 6270:6270 $coreimage blockstack api start-foreground --password $1 --api_password $1
    elif [[ $(uname) == 'Windows' ]]; then
      echo "Don't know if this works!!!"
      docker run -d --name $corecontainer -v $homedir:$containerdir -p 6270:6270 $coreimage blockstack api start-foreground --password $1 --api_password $1
    fi
  fi

}

browser () {
  # Check if the blockstack-browser-* containers are running or stopped. 
  if [ "$(docker ps -q -f name=$browsercontainer)" ]; then
    echo "containers are already running"
    exit 1
  elif [ ! "$(docker ps -q -f name=$browsercontainer)" ]; then
    if [ "$(docker ps -aq -f status=exited -f name=$browsercontainer)" ]; then
      # cleanup old containers if they are still around
      echo "removing old container..."
      docker rm $(docker ps -a -f name=$browsercontainer -q)
    fi
    
    # If there are no existing blockstack-browser-* containers, run them
    if [[ $(uname) == 'Linux' ]]; then
      docker run -d --name $browsercontainer-static -p 8888:8888 $browserimage blockstack-browser
      docker run -d --name $browsercontainer-cors -p 1337:1337 $browserimage blockstack-cors-proxy
    elif [[ $(uname) == 'Darwin' ]]; then
      docker run -d --name $browsercontainer-static -p 8888:8888 $browserimage blockstack-browser
      docker run -d --name $browsercontainer-cors -p 1337:1337 $browserimage blockstack-cors-proxy
    elif [[ $(uname) == 'Windows' ]]; then
      echo "Don't know if this works!!!"
      docker run -d --name $browsercontainer-static -p 8888:8888 $browserimage blockstack-browser
      docker run -d --name $browsercontainer-cors -p 1337:1337 $browserimage blockstack-cors-proxy
    fi
  fi
}

stop () {
  bc=$(docker ps -a -f name=$browsercontainer -q)
  cc=$(docker ps -f name=$corecontainer -q) 
  if [ ! -z "$cc" ]; then
    echo "stopping the running blockstack-api container"
    docker stop $cc
    docker rm $cc
  fi
  
  if [ ! -z "$bc" ]; then
    echo "stopping the running blockstack-browser containers"
    docker stop $bc
    docker rm $bc
  fi
}

enter () {
  echo "entering docker container"
  docker exec -it $corecontainer /bin/bash
}

logs () {
  echo "streaming logs for blockstack-api container"
  docker logs $corecontainer -f
}

push () {
  echo "pushing build container up to quay.io..."
  docker push $coreimage
}

commands () {
  cat <<-EOF
bsdocker commands:
  start -> start the blockstack api server
  stop -> stop the blockstack api server
  setup -> run the setup for blockstack and generate a wallet
  logs -> access the logs from the blockstack api server
  enter -> exec into the running docker container
  browser -> run the two browser containers as well
EOF
}

case $1 in
  setup)
    setup $2
    ;;
  stop)
    stop
    ;;
  logs)
    logs
    ;;
  build)
    build 
    ;;
  enter)
    enter 
    ;;
  browser)
    browser 
    ;;
  start)
    start $2
    ;;
  push)
    push
    ;;
  *)
    commands
    ;;
esac
