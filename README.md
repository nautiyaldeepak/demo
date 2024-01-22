Symfony Demo Application | Lingoda Assignment
=============================================

## Summary
We'll be deploying 2 microservices on Kubernetes. Our first microservice will be a httpd server & our second microservice will be running php-fpm8.2. The php-fpm server will be using TCP socket at port 9000. The user request will interact with httpd server & httpd server is going to act as a proxy server which is going to proxy forward the request to fpm server.  

## Requirements
#### Clone repository
```
$ git clone https://github.com/nautiyaldeepak/demo.git
$ cd /demo
```

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
$ kubectl apply -f kubernetes/namespace.yaml
$ kubectl apply -f kubernetes/httpd-deployment.yaml
$ kubectl apply -f kubernetes/php-fpm-deployment.yaml
```
NOTE: 
1. The images used in kubernetes deployments are `public` images, so they can be pulled anywhere. The reason for keeping the images public is because the assignment allows us to keep the repository public. If the assignment would have asked to keep the repository private then I would also have kept the images private.
2. The images have been build on an `arm64` CPU architecture. Please make sure that your setup has a same architecture. Run the command `$ arch` on Mac terminal to know your systems architecture. If your deploying this on managed Kubernetes then make sure your nodes have `arm64` architecture. When creating managed nodeGroup on EKS it gives you to select the architecture type. If the architecture if not arm64, in that case you'll have to build the docker images first on your own system (follow previous steps) & then use those images in kubernetes manifests. If architecture is the issue then you might see an error like this one -> `exec /usr/sbin/php-fpm8.2: exec format error`. If you still face issue with it, contact me.

#### Testing Task 1
We're also deploying ingress resource but since there is no DNS mapping, we'll use port-forwading to test our task.
```
$ kubectl port-forward svc/httpd-server 8080:80 -n testing
```
Now, access the URL `http://127.0.0.1:8080` on your browser. Make sure it is `http` & not `https`, since there are no certificates. Use the URL to add/edit some content on the website (We're going to use this in Task 2).

NOTE: When accessing the URL `http://127.0.0.1:8080`, there are some APIs which are not working. It'll give you `403 AccessDenied` error. This is an application level issue, therefore I haven't addressed them. When you're logging into the app make sure you use ADMIN_USER and not the other one.

## Task 2
#### Database Migration
There is a Sqlite database running on directory `/app/data/`. There is no Persistent Volume attached to the pod, the storage is ephemeral. So, basically here we need to migrate `/app/data/database.sqlite`. 
In order to successfully migrate our data from current pod to the new pod we're using `postStart` lifeCycle hook on our `php-fpm` deployment. The lifecycle hook will execute a migration script which is going to copy `/app/data/database.sqlite` from the old container to the new container.
This migration script has already been made part of `task 1`. So when you deployed task 1 the `migration script` was also deployed with the `php-fpm` deployemnt.

#### Testing Task 2
Our kubernetes deployments are already running from Task 1. We just need to update our `php-fpm` image. 
In `kubernetes/php-fpm-deployment.yaml` file change the image tag from `public.ecr.aws/o6a6b5p9/application:php-fpm-v1` to `public.ecr.aws/o6a6b5p9/application:php-fpm-v2`. Both these images are exactly same, so you can also swhich it back from `v2` to `v1` as well.
Now deploy the new image on kubernetes
```
$ kubectl apply -f kubernetes/php-fpm-deployment.yaml
```
This command will create a new pod and this new pod will copy the `/app/data/database.sqlite` from the previous running pod to this new pod & only after that this new pod will get into `Running` state & old pod will be `Terminated`.

Now lets check the content of this new pod.
```
$ kubectl port-forward svc/httpd-server 8080:80 -n testing
```
Again access the URL `http://127.0.0.1:8080`. Check if the updated content from Task 1 still exists.

NOTE: The migration-script is written in such a manner that if the deployment if happening for the first time then it'll know that there is no migration necessary.

## Task 3
#### Potential Scaling Issues with Current Deployment
Currently our php-fpm microservice is stateful, as the database is within the microservice itself. Due to this nature of the application it is impossible to scale the application hozizontally. The problem with horizontal scaling with current setup is that each replica of that microservice will have its own database. Therefore we can only have 1 replica of this microservice & it can only be scaled vertically & vertically scaling in this setup will bring challenges of its own.

SOLUTION: In order to overcome this challenge we need to make our php-fpm microservice stateless. To do that we need to remove the database from within the application & manage it seperately. We can run a sqlite database as a stateful application on kubernetes or this application also allows us to use MYSQL & POSTGRES as well. We can also use AWS RDS managed service for database. Once we remove the database from the php-fpm microservice, the php-fpm microservice will become stateless. then it'll be possible to scale the application horizontally. Ofcourse, the php-fpm will access the external database using creds (database credentials will need to be updated in `.env` file).