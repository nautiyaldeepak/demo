Symfony Demo Application | Lingoda Assignment
=============================================

## Summary
We'll be deploying 2 microservices on Kubernetes. Our first microservice will be a httpd server & our second microservice will be running php-fpm8.2. The php-fpm server will be using TCP socket at port 9000. The user request will interact with httpd server & httpd server is going to act as a proxy server which is going to proxy forward the request to fpm server.  

## Task 1
#### Dockerize `httpd` server & `php-fpm`
```
$ docker build -t httpd:v1 -f Dockerfile.httpd .
$ docker build -t php-fpm:v1 -f Dockerfile.php-fpm .
```

#### Push docker images to a container registry.
The below example is to push docker images to public Elastic Container Registry(ECR).
```
$ docker tag httpd:v1 public.ecr.aws/1a2b3c4d5e/application:httpd-v1
$ docker tag php-fpm:v1 public.ecr.aws/1a2b3c4d5e/application:php-fpm-v1
$ docker push public.ecr.aws/1a2b3c4d5e/application:httpd-v1
# docker push public.ecr.aws/1a2b3c4d5e/application:php-fpm-v1
```
NOTE: If you're using some other container registry then just replace the `public.ecr.aws/1a2b3c4d5e/application` part with your own repository URL.

#### Deploy the microservices on Kubernetes
The below commands will create a namespace `testing` & all the resources will be deployed in that namespace.
```
$ kubectl apply -f namespace.yaml
$ kubectl apply -f httpd-deployment.yaml
$ kubectl apply -f php-fpm-deployment.yaml
```
NOTE: 
1. The images used in kubernetes deployments are `public` images, so they can be pulled anywhere. The reason for keeping the images public is because the assignment allows us to keep the repository public. If the assignment would have asked to keep the repository private then I would also have kept the images private.
2. The images have been build on an `arm64` CPU architecture. Please make sure that your setup has a same architecture. Run the command `$ arch` on Mac terminal to know your systems architecture. If your deploying this on managed Kubernetes then make sure your nodes have `arm64` architecture. When creating managed nodeGroup on EKS it gives you to select the architecture type. If the architecture if not arm64, in that case you'll have to build the docker images first on your own system (follow previous steps) & then use those images in kubernetes manifests. If architecture is the issue then you might see an error like this one -> `exec /usr/sbin/php-fpm8.2: exec format error`