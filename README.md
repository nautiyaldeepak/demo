Symfony Demo Application | Lingoda Assignment
=============================================

## Summary
We'll be deploying 2 microservices on Kubernetes. Our first microservice will be a httpd server & our second microservice will be running php-fpm8.2. The php-fpm server will be using TCP socket at port 9000. The user request will interact with httpd server & httpd server is going to act as a proxy server which is going to proxy forward the request to fpm server.  

## Requirements
#### Start Minikube
You can skip this step if you're using some other cluster of your own.
```
$ minikube start
```
#### Clone repository
```
$ git clone https://github.com/nautiyaldeepak/demo.git
$ git clone https://github.com/kubernetes/autoscaler.git
```
#### Change directory for task 1 & 2
```
$ cd demo/
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
The below commands will create a namespace `testing` & all the resources will be deployed in that namespace. I already have prebuild images which are being used in these deployments.
```
$ kubectl apply -f kubernetes/namespace.yaml
$ kubectl apply -f kubernetes/httpd-deployment.yaml
$ kubectl apply -f kubernetes/php-fpm-deployment.yaml
```
NOTE: 
1. The images have been built on an `arm64` CPU architecture. Please make sure that your setup has a same architecture. Run the command `$ arch` on Mac terminal to know your system's architecture. If you're deploying this on managed Kubernetes then make sure your nodes have `arm64` architecture. When creating managed nodeGroup on EKS it gives you an option to select the architecture type. If the architecture is not arm64, in that case you'll have to build the docker images first on your own system (follow previous steps) & then use those images in kubernetes manifests. If architecture is the issue then you might see an error like this one -> `exec /usr/sbin/php-fpm8.2: exec format error`. If you still face issue with it, contact me.

#### Testing Task 1
We'll use port-forwading to test our task.
```
$ kubectl port-forward svc/httpd-server 8080:80 -n testing
```
Now, access the URL `http://127.0.0.1:8080` on your browser. Make sure it is `http` & not `https`, since there are no certificates. Use the URL to add/edit some content on the website (We're going to use this in Task 2).

NOTE: When accessing the URL `http://127.0.0.1:8080`, there are some APIs which are not working. It'll give you `403 AccessDenied` error. This is an application level issue, therefore I haven't addressed them. When you're logging into the app make sure you use `ADMIN_USER` and not the `REGULAR_USER`.

## Task 2
#### Database Migration
There is a Sqlite database running on directory `/app/data/`. There is no Persistent Volume attached to the pod, the storage is ephemeral. So, basically here we need to migrate `/app/data/database.sqlite`. 
In order to successfully migrate our data from current pod to the new pod we're using `postStart` lifeCycle hook on our `php-fpm` deployment. The lifecycle hook will execute a migration script which is going to copy `/app/data/database.sqlite` from the old container to the new container.
This migration script has already been made part of `task 1`. So when you deployed task 1 the `migration script` was also deployed with the `php-fpm` deployment.

#### Testing Task 2
Our kubernetes deployments are already running from Task 1. We just need to redeploy our `php-fpm` pod. Use the command below to rollout a new pod. 
```
$ kubectl rollout restart deployment php-fpm -n testing
```
This command will create a new pod and this new pod will copy the `/app/data/database.sqlite` from the previous running pod to this new pod & only after that this new pod will get into `Running` state & old pod will be `Terminated`.

Now, lets check the content of this new pod.
```
$ kubectl port-forward svc/httpd-server 8080:80 -n testing
```
Again access the URL `http://127.0.0.1:8080`. Check if the updated content from Task 1 still exists.

NOTE: The migration-script is written in such a manner that if the deployment if happening for the first time then it'll know that there is no migration necessary.

## Task 3
#### Scaling the Deployment
 1. Currently our php-fpm microservice is stateful, as the database is within the microservice itself. 
 2. Due to this nature of the application it is impossible to scale the application horizontally, as each microservice will have its own database. So we're going to scale this application vertically.

#### Setting up Vertical Pod Autoscaling
Deploying metrics-server for VPA. VPA will use data from metrics-server to analyse the metrics of our microservices.
If you're running on minikube then use the following command
```
$ minikube addons enable metrics-server
```
OR
```
$ kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```
After deploying metrics-server, we'll deploy Vertical Pod Autoscaler custom resource from the autoscaler repository which we cloned earlier.
```
$ cd ../autoscaler/vertical-pod-autoscaler/
$ ./hack/vpa-up.sh
```
Now we'll deploy VPA resource for or `php-fpm` deployment.
```
$ ../../demo
$ kubectl apply -f kubernetes/php-fpm-vpa.yaml
```
 1. The VPA only supports scaling on metrics cpu & memory. 
 2. The above VPA is using `standard` vpa recommender. 
 3. App will vertically scale up if CPU/Memory usage crosses 90% threshold. The autoscaler will double the resource for which the threshold crossed.

#### Challenges with the Current Setup
 1. The main issue with the current architecture is that, database and the app are running on the same container.
 2. Our app is now acting as a stateful application which is not fault tolerant & also not highly scalable.
 3. We cannot not horizontal pod autoscaling for our app, as we cannot have have each replica running its own database.
 4. The same problem goes with database as well. If our pod is deleted due to some reason all our data is lost.
 5. Also, the scaling of database is also very difficult as the storage is the setup is ephemeral.

#### New Setup to resolve all the challenges
Check the diagram below
![diagram1 (1)](https://github.com/symfony/demo/assets/30626234/3d3881dd-53dc-4fc6-8cb0-fb7ea6aa7771)
 1. In the diagram above we're segregating the database from the app.
 2. The app is running independently of the database & now our php-fpm is stateless. If our app wants to interact with database it'll make the request to the database.
 3. Since our php-fpm app in this setup is stateless we can apply horizontal pod autoscaling on this deployment. HPA also provides us with the flexibility to use custom-metrics.
 4. With horizontal pod autoscaling we can deploy multiple replicas for our app if the resource utilization crosses a certain threshold. This kind of setup will make our app fault tolerant & highly scalable.
 5. In this new setup, we'll manage our database independently. Our database can be deployed as a statefulset or we can also use AWS managed service (AWS RDS).