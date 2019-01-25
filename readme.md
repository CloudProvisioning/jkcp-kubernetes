# Cloud provisoning - Demo 4 instructions

Links:
- Cloud provisioning project GitHub - https://github.com/CloudProvisioning
- Cloud provisioning project Demo4 backend app image - jkdc/flask-demo-app-v4:latest

Prerequisites:
- 4 virtual machines with:
	- Linux (tested on Ubuntu 18.04)
	- Docker.io (tested on 17.12.1-ce)
	- Kubernetes (tested on 1.12.1)
- Node.js for build frontend (tested on 8.10.0)
- Docker.io for build frontend app image (tested on 17.12.1-ce)

Steps:
## 1. Kubernetes installation, on all machines:
	sudo swapoff -a
	as root only
	# sudo su
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
	apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
	apt update
	apt install kubeadm
	
## 2. Kubernetes cluster initialization, on master node:
	kubeadm init --pod-network-cidr=10.244.0.0/16
	# copy output with join command and token here, required for step 4
	mkdir -p $HOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config	
	
## 3. Install Flannel, on master node:
	kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
	
## 4. On all machines, except master node:
	# run join command from step 2 output and run
	kubectl get nodes
	# output must be like in example:
	NAME          STATUS   ROLES    AGE   VERSION
	cpn1          Ready    <none>   2d   v1.12.1
	cpn2          Ready    <none>   2d   v1.12.1
	cpn3          Ready    <none>   2d   v1.12.1
	cpm           Ready    master   3d   v1.12.1
	
## 5. Create ConfigMap with configuration settings:	
	# on master node run
	git clone https://github.com/CloudProvisioning/jkcp-kubernetes.git
    
	# locate inside the jkcp-kubernetes.git repo demo 4 folder and run
    
    	./init-demo-app-config-map.sh    
	kubectl create -f demo-app-config-map.yml
    
	# check it
	kubectl describe configmap demo-app-config-map
	
## 6. Deploy CockroachDB:
	# locate inside the jkcp-kubernetes.git repo demo 4 folder and run
	kubectl create -f cockroachdb-deployment-services-pvs.yaml
    
	# check pods
	kubectl get pods
    
	# output must contain like in example:
	NAME                              READY   STATUS    RESTARTS   AGE
	cockroachdb-0                     1/1     Running   0          1m
	cockroachdb-1                     1/1     Running   0          1m
	cockroachdb-2                     1/1     Running   0          1m
	
## 7. Prepare CockroachDB:
	# access any cockroach pod from stateful set, for example cockroachdb-0
	kubectl exec -ti cockroachdb-0 sh
    
	# create database from inner terminal
	./cockroach sql --execute "CREATE DATABASE cp_test_db" --insecure
	
	# deploy pgweb for convenience, locate inside the jkcp-kubernetes.git repo demo 4 folder and run
	kubectl create -f pgweb-deployment-service.yml
    
	# go to http://<your-cluster-ip>:31000 and connect to database using
	# host: cockroachdb-public
	# port: 26257
	# password leave empty
	# database: cp_test_db
	# ssl mode: disable
	# go to Query section on top of the page and run
	CREATE TABLE "people" (
	  "id" SERIAL PRIMARY KEY,
	  "first_name" varchar NOT NULL,
	  "last_name" varchar NOT NULL,
	  "age" int NOT NULL,
	  "employment" varchar NOT NULL,
	  "location" varchar NOT NULL,
	  "pet_name" varchar NOT NULL,
	  "favorite_color" varchar NOT NULL,
	  "server_id" int NOT NULL,
	  "add_timestamp" varchar NOT NULL
	);
	# check side menu for table "people"

## 8. Deploy Flask backend, on master node:
	# locate inside the jkcp-kubernetes.git repo demo 4 folder and run
	kubectl create -f backend-deployment-service.yml

	# check it in browser, go to http://<your-cluster-ip>:31651/

## 9. Prepare frontend application, on machine with Node.js and Docker
	git clone https://github.com/CloudProvisioning/vue-demo-app.git
	cd vue-demo-app
	npm install
	# check it
	npm run serve

    	# go to http://localhost:8080 and make sure it works and then disable by ctrl+c in console
	# build frontend project
	npm run build
 
	# build frontend application docker image, tag it and push to docker hub
	sudo docker build -t vue-demo-app .
	sudo docker tag vue-demo-app jkdc/vue-demo-app:latest
	sudo docker push jkdc/vue-demo-app:latest
	
## 10. Deploy frontend application:
	# locate inside the jkcp-kubernetes.git repo demo 4 folder, open frontend-deployment-service.yml
	# change Deployment section, from image: "jkdc/vue-demo-app:latest" to image: "<your-docker-hub-username>/vue-demo-		# app:latest"
	
	kubectl create -f frontend-deployment-service.yml
	
## 11. Run application:
	# go to http://<your-cluster-ip>:32401
	# View all data page show all data from database, serverId provide id of server which was generate particular row
	# Add data page allows to add specified number of new rows to database, data will generate by server
	# Remove data page allows to delete specified number of new rows from database

## 12. OPTIONAL. Deploy Kubernetes dashboard:
	# locate inside the jkcp-kubernetes.git repo demo 4 folder and run
	kubectl create -f k8s-dashboard-deployment-service.yaml

## 13. OPTIONAL. Expose CockroachDB Admin UI:
	# Create another cockroachdb service with type NodePort, for example:
	apiVersion: v1
	kind: Service
	metadata:
	  name: cockroachdb-public-ui
	  labels:
		app: cockroachdb
	spec:
	  type: NodePort
	  ports:
	  - port: 8080
		targetPort: 8080
		name: http
		nodePort: 31010
	  selector:
		app: cockroachdb
	# go to http://<your-cluster-ip>:31010

## 14. OPTIONAL. Istio installing.
	# For installing Istio you could use next manual:
	https://istio.io/docs/setup/kubernetes/quick-start/
	
	# For inject envoy-proxe to demo application container there is needed to make next updates during applying of some yaml 	 # files:
	
	kubectl apply -f <(istioctl kube-inject -f frontend-deployment-service.yml)
	kubectl apply -f <(istioctl kube-inject -f backend-deployment-service.yml)
	kubectl apply -f <(istioctl kube-inject -f pgweb-deployment-service.yml)
	
	# Note: for another containers there MUST NOT be port with name "grps" because it causes envoy-proxy injecting without 
	# any confirmation. So for correct CockroachDB install you have to use last repository version.
	
## 15. OPTIONAL. Istio. Kiali dashboard install.
	# For installing Kiali you could use next manual:
	https://istio.io/docs/tasks/telemetry/kiali/
	
# Known issues:
- hardcoded link in frontend application  (fixed)
- insecure http connection
- CockroachBD in insecure mode 
- after 1+ week CockroachDB cluster has errors, stop working, has pod state CrashLoopBackoff
