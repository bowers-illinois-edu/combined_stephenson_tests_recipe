D_USERNAME=$USER
IMAGE=jake_dev
TAG=0.1

# This is the only one that matters
DOCKER_IMA=jwbowers/$IMAGE:$TAG
NAME=jake_dev

hostname="`hostname -s`-docker"
ip=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')
xhost + $ip


echo "starting docker with image: $DOCKER_IMA"
docker run -ti -e DISPLAY=$ip:0 \
    -v $HOME/repos/Jake/home-jwbowers:/home/$D_USERNAME \
    -h $hostname \
    --network host \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    --name $NAME \
    $DOCKER_IMA bash

# To re-enter from another terminal
# NAME=jake_dev; docker exec -ti $NAME bash

# To clean up
# docker rm $(docker ps -a -f status=exited -q)
