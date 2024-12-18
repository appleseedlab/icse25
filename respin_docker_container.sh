#!/bin/bash

container_name=$1
image_name=$2

docker stop $container_name
docker rm $container_name

docker build . -t $image_name
docker run -dit --name $container_name $image_name bash
