
export DISTRO=ubuntu
export IMAGE=jake_dev
export TAG=0.1
export D_USERNAME=$USER
docker build -f $DISTRO/Dockerfile \
       -t jwbowers/$IMAGE:$TAG \
       --build-arg D_USERNAME \
       --rm=true .

echo 'Push commands:'
echo "   docker push jwbowers/$IMAGE:${TAG}"

echo 'To create singularity image:'
echo "  ./docker2singularity jwbowers/$IMAGE:${TAG}"
