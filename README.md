A) Strimzi operator Installation

It is a step-by-step guide to installing Kafka and its components on k8s.


1. create namespace strimzi-operator and kafka-poc

kubectl create namespace strimzi-operator-ns
-
namespace/strimzi-operator-ns created

kubectl create namespace kafka-poc-ns
-
namespace/kafka-poc-ns created

kubectl get ns
-
NAME                  STATUS   AGE
default               Active   24m
kafka-poc-ns          Active   6s
kube-node-lease       Active   24m
kube-public           Active   24m
kube-system           Active   24m
strimzi-operator-ns   Active   13s

2.  Strimzi operator Installation
    
    It is a step-by-step guide to installing Kafka and its components on k8s.


2.1 Downloading Strimzi


CHART_VERSION=0.32.0
wget https://github.com/strimzi/strimzi-kafka-operator/releases/download/${CHART_VERSION}/strimzi-kafka-operator-helm-3-chart-${CHART_VERSION}.tgz


tar -xvf strimzi-kafka-operator-helm-3-chart-${CHART_VERSION}.tgz
cd strimzi-kafka-operator


2.2 install helm repo

helm repo add strimzi https://strimzi.io/charts/

helm repo list
-
NAME              	URL                                                 
strimzi           	https://strimzi.io/charts/      

helm repo update

helm search repo strimzi 
-
NAME                          	CHART VERSION	APP VERSION	DESCRIPTION                                       
strimzi/strimzi-drain-cleaner 	0.4.2        	0.4.2      	Utility which helps with moving the Apache Kafk...
strimzi/strimzi-kafka-operator	0.33.2       	0.33.2     	Strimzi: Apache Kafka running on Kubernetes  


2.3 Edit the values.yaml and add the namespace in which the kafka cluster needs to be installed.

watchNamespaces:
 - kafka-poc-ns

2.4. Install the helm chart.


helm install strimzi strimzi/strimzi-kafka-operator --namespace strimzi-operator-ns
-
NAME: strimzi
LAST DEPLOYED: Thu Mar 16 17:14:16 2023
NAMESPACE: kafka-poc-ns
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Thank you for installing strimzi-kafka-operator-0.33.2

2.5. check the pod deployed for strimzi operator

kubectl get pods -n strimzi-operator-ns
-
NAME                                        READY   STATUS    RESTARTS   AGE
strimzi-cluster-operator-6977966d6d-lfsfd   1/1     Running   0          41s

2.6. Describe the pod

kubectl describe pod strimzi-cluster-operator-6977966d6d-j8svq -n strimzi-operator-ns


 
B) To create an IAM OIDC identity provider for your cluster with eksctl


1. Determine whether you have an existing IAM OIDC provider for your cluster.
Retrieve your cluster's OIDC provider ID and store it in a variable.

oidc_id=$(aws eks describe-cluster --name eks-kafka-connect --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)

2. Determine whether an IAM OIDC provider with your cluster's ID is already in your
account.

aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4


3. If output is returned, then you already have an IAM OIDC provider for your
cluster and you can skip the next step. If no output is returned, then you must
create an IAM OIDC provider for your cluster.

4. Create an IAM OIDC identity provider for your cluster with the following command. Replace eks-cube-dev with your own value.

eksctl utils associate-iam-oidc-provider --cluster eks-kafka-connect --approve

5. Check again whether an IAM OIDC provider with your cluster's ID is created in your account.

aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4
-
0CC0A3A3AF9A13C2D33E5E4966BF1A6D"



C) Deploy and test the Amazon EBS CSI driver

Deploy the Amazon EBS CSI driver:

1.    Download an example IAM policy with permissions that allow your worker nodes to create and modify Amazon EBS volumes:

curl -o example-iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/v0.9.0/docs/example-iam-policy.json
-
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   599  100   599    0     0    756      0 --:--:-- --:--:-- --:--:--   762


2.    Create an IAM policy named Amazon_EBS_CSI_Driver:

aws iam create-policy --policy-name AmazonEKS_EBS_CSI_Driver_Policy --policy-document file://example-iam-policy.json
-
{
    "Policy": {
        "PolicyName": "AmazonEKS_EBS_CSI_Driver_Policy",
        "PolicyId": "ANPAXNAXRAAKGMLETKJDU",
        "Arn": "arn:aws:iam::509002973204:policy/AmazonEKS_EBS_CSI_Driver_Policy",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "PermissionsBoundaryUsageCount": 0,
        "IsAttachable": true,
        "CreateDate": "2023-03-17T12:06:56+00:00",
        "UpdateDate": "2023-03-17T12:06:56+00:00"
    }
}

3.    View your cluster's OIDC provider URL:

aws eks describe-cluster --name eks-cube-test --query "cluster.identity.oidc.issuer" --output text
-
https://oidc.eks.us-east-1.amazonaws.com/id/9183AC249297ECB8A04B1FD9C0DDEB30



4.    Create the following IAM trust policy file:

cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::509002973204:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/9183AC249297ECB8A04B1FD9C0DDEB30"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/9183AC249297ECB8A04B1FD9C0DDEB30:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF


5.    Create an IAM role:

aws iam create-role \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --assume-role-policy-document file://"trust-policy.json"

6.    Attach your new IAM policy to the role:

aws iam attach-role-policy \
--policy-arn arn:aws:iam::509002973204:policy/AmazonEKS_EBS_CSI_Driver_Policy \
--role-name AmazonEKS_EBS_CSI_DriverRole


7.    To deploy the Amazon EBS CSI driver, run one of the following commands based on your Region:

All Regions other than China Regions:

kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"


8.    Annotate the ebs-csi-controller-sa Kubernetes service account with the Amazon Resource Name (ARN) of the IAM role that you created earlier:

kubectl annotate serviceaccount ebs-csi-controller-sa \
-n kube-system \
eks.amazonaws.com/role-arn=arn:aws:iam::509002973204:role/AmazonEKS_EBS_CSI_DriverRole

9.    Delete the driver pods:

kubectl delete pods \
-n kube-system \
-l=app=ebs-csi-controller



D) Test the Amazon EBS CSI driver:

You can test your Amazon EBS CSI driver with an application that uses dynamic provisioning. The Amazon EBS volume is provisioned on demand.

1.    Clone the aws-ebs-csi-driver repository from AWS GitHub:

git clone https://github.com/kubernetes-sigs/aws-ebs-csi-driver.git

2.    Change your working directory to the folder that contains the Amazon EBS driver test files:

cd aws-ebs-csi-driver/examples/kubernetes/dynamic-provisioning/

3.    Create the Kubernetes resources required for testing:

kubectl apply -f manifests/

Note: The kubectl command creates a StorageClass (from the Kubernetes website), PersistentVolumeClaim (PVC) (from the Kubernetes website), and pod. The pod references the PVC. An Amazon EBS volume is provisioned only when the pod is created.

4.    Describe the ebs-sc storage class:

kubectl describe storageclass ebs-sc

5.    Watch the pods in the default namespace and wait for the app pod's status to change to Running. For example:

kubectl get pods --watch

6.    View the persistent volume created because of the pod that references the PVC:

kubectl get pv

7.    View information about the persistent volume:

kubectl describe pv your_pv_name

Note: Replace your_pv_name with the name of the persistent volume returned from the preceding step 6. The value of the Source.VolumeHandle property in the output is the ID of the physical Amazon EBS volume created in your account.

8.    Verify that the pod is writing data to the volume:

kubectl exec -it app -- cat /data/out.txt

Note: The command output displays the current date and time stored in the /data/out.txt file. The file includes the day, month, date, and time.

8.    Delete that the pod once verify the volume:

kubectl delete pods app



E) Kafka Cluster Installation

For the poc we will install single node kafka cluster.

1. Create kafka-persistent-single.yaml file using below.


2. Apply the template to create Kafka cluster.

cd kube

kubectl apply -f kafka-persistent-single.yaml


3.  Check if cluster is created properly.

kubectl get kafka -n kafka-poc-ns
-
NAME                DESIRED KAFKA REPLICAS   DESIRED ZK REPLICAS   READY   WARNINGS
kafka-poc-cluster   1                    

4. check if all pods are in running state.

kubectl get pods -n kafka-poc-ns
-
NAME                                                READY   STATUS    RESTARTS   AGE
kafka-poc-cluster-entity-operator-bd65b74f7-fw9zf   3/3     Running   0          2m19s
kafka-poc-cluster-kafka-0                           1/1     Running   0          3m6s
kafka-poc-cluster-zookeeper-0                       1/1     Running   0          4m

5. create topic using the kafka-topic.yaml and update strimzi.io/cluster: kafka-poc-cluster as per your cluster name.

strimzi.io/cluster: kafka-poc-cluster

6. Deploy topic using the cluster operator.

kubectl apply -f kafka-topic.yaml
-
kafkatopic.kafka.strimzi.io/my-topic created

7. check if the topic is created properly.

kubectl get kafkatopic
-
NAME       CLUSTER             PARTITIONS   REPLICATION FACTOR   READY
my-topic   kafka-poc-cluster   1            1                    

8. Insert data into the kafka topic my-topic, use ctrl+c to exit

kubectl run kafka-producer -n kafka-poc-ns -ti --image=quay.io/strimzi/kafka:0.32.0-kafka-3.3.1 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server kafka-poc-cluster-kafka-bootstrap:9092 --topic my-topic
-
If you don't see a command prompt, try pressing enter.
>1
>2
>3
>4
>5

9. Consume data from topic my-topic , use ctrl+c to exit

kubectl run kafka-consumer -n kafka-poc-ns -ti --image=quay.io/strimzi/kafka:0.32.0-kafka-3.3.1 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server kafka-poc-cluster-kafka-bootstrap:9092 --topic my-topic --from-beginning
-
If you don't see a command prompt, try pressing enter.
1
2
3
4
5


F) Kafka Connect Installation

1. Download kafka-connect.yaml template.

cd kube/kafka-connect.yaml

2. Create ECR repo de_kafka_connect to store the kafka connect build image.

repo name -> de_kafka_connect

3. Create a registry secret within the above (kafka-poc-ns) namespace that would be used to pull an image from a private ECR repository:

kubectl create secret docker-registry regcred \
--docker-server=509002973204.dkr.ecr.us-east-1.amazonaws.com \
--docker-username=AWS \
--docker-password=$(aws ecr get-login-password) \
--namespace=kafka-poc-ns

4. create file kafka-connect.yaml to deploy kafka connect.

cd kube/kafka-connect.yaml

5. Apply the above template to deploy kafka connect.

kubectl apply -f kafka-connect.yaml

6. Check the deployment using the below commands.

kubectl get pods -n kafka-poc-ns
-
NAME                                                READY   STATUS    RESTARTS   AGE
kafka-connect-poc-cluster-connect-build             1/1     Running   0          19s
kafka-poc-cluster-entity-operator-bd65b74f7-fw9zf   3/3     Running   0          17m
kafka-poc-cluster-kafka-0                           1/1     Running   0          18m
kafka-poc-cluster-zookeeper-0                       1/1     Running   0          19m
strimzi-cluster-operator-6977966d6d-j8svq           1/1     Running   0          102m


7. check kafka connect cluster should be TRUE

kubectl get kc -n kafka-poc-ns
-
NAME                        DESIRED REPLICAS   READY
-
kafka-connect-poc-cluster   1                  True

8. aslo check ECR is image has been pushed.

Repository : de_kafka_connect
Image tags: latest
URI : 509002973204.dkr.ecr.us-east-1.amazonaws.com/de_kafka_connect:latest
Digest : sha256:6bd54ec22743953b404b636d0bc1131d10373138faae6efbb057c7e0567294a2


G) Install mongo


1. create namespace MongoDB

kubectl create namespace mongodb

2. create file mongo_statefulset.yaml

cd kube/mongo_statefulset.yaml

3. Apply the above template to deploy standalone MongoDB.

kubectl apply -f mongo_statefulset.yaml
-
statefulset.apps/mongodb-standalone created

4. Check if MongoDB started, Wait for the pod to be in a running state.

kubectl get pods -n mongodb
-
NAME                   READY   STATUS    RESTARTS   AGE
mongodb-standalone-0   1/1     Running   0          14s

5. Get inside the mongo shell.

kubectl exec -it mongodb-standalone-0 -n mongodb -- /bin/sh
-
# mongo
MongoDB shell version v4.0.8
connecting to: mongodb://127.0.0.1:27017/?gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("e450436f-6228-4df7-bed2-74e8b4d70fb0") }
MongoDB server version: 4.0.8
Welcome to the MongoDB shell.
For interactive help, type "help".
For more comprehensive documentation, see
	http://docs.mongodb.org/
Questions? Try the support group
	http://groups.google.com/group/mongodb-user
> 

5.1. connect db using credentails 

> use admin
switched to db admin
>  db.auth("admin","password")
1

5.2. initate the mongodb primary mode

> rs.initiate()
{
	"info2" : "no configuration specified. Using a default configuration for the set",
	"me" : "mongodb-standalone-0:27017",
	"ok" : 1
}
rs0:SECONDARY> rs.conf()
{
	"_id" : "rs0",
	"version" : 1,
	"protocolVersion" : NumberLong(1),
	"writeConcernMajorityJournalDefault" : true,
	"members" : [
		{
			"_id" : 0,
			"host" : "mongodb-standalone-0:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		}
	],
	"settings" : {
		"chainingAllowed" : true,
		"heartbeatIntervalMillis" : 2000,
		"heartbeatTimeoutSecs" : 10,
		"electionTimeoutMillis" : 10000,
		"catchUpTimeoutMillis" : -1,
		"catchUpTakeoverDelayMillis" : 30000,
		"getLastErrorModes" : {
			
		},
		"getLastErrorDefaults" : {
			"w" : 1,
			"wtimeout" : 0
		},
		"replicaSetId" : ObjectId("64199a5fce80ce02ca996dc2")
	}
}
rs0:PRIMARY> db.createCollection("fruits")
{
	"ok" : 1,
	"operationTime" : Timestamp(1679399589, 1),
	"$clusterTime" : {
		"clusterTime" : Timestamp(1679399589, 1),
		"signature" : {
			"hash" : BinData(0,"4mlu4JBOAW3CXLkbnKZmIfk39Bg="),
			"keyId" : NumberLong("7212966019613065217")
		}
	}
}
rs0:PRIMARY> db.fruits.insertMany([ {name: "apple", origin: "usa", price: 5}, {name: "orange", origin: "italy", price: 3}, {name: "mango", origin: "malaysia", price: 3} ])
{
	"acknowledged" : true,
	"insertedIds" : [
		ObjectId("64199aabcbf9c20ec3d8ab81"),
		ObjectId("64199aabcbf9c20ec3d8ab82"),
		ObjectId("64199aabcbf9c20ec3d8ab83")
	]
}
rs0:PRIMARY> show dbs
admin   0.000GB
config  0.000GB
local   0.000GB
rs0:PRIMARY> db.fruits.find().pretty()
{
	"_id" : ObjectId("64199aabcbf9c20ec3d8ab81"),
	"name" : "apple",
	"origin" : "usa",
	"price" : 5
}
{
	"_id" : ObjectId("64199aabcbf9c20ec3d8ab82"),
	"name" : "orange",
	"origin" : "italy",
	"price" : 3
}
{
	"_id" : ObjectId("64199aabcbf9c20ec3d8ab83"),
	"name" : "mango",
	"origin" : "malaysia",
	"price" : 3
}
rs0:PRIMARY> 




6. Create a service to connect mongo from outside of the pod using the below template. 

cd kube/mongo_service.yaml

7. Deploy the above file to create a service. 

kubectl apply -f mongo_service.yaml
-
service/database created

8. check the service status

kubectl get service -n mongodb
-
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
database   ClusterIP   None         <none>        <none>    7s



(H) Deploy kafka connectors to source data from mongo

1. Consume from the beginning.
https://www.mongodb.com/docs/kafka-connector/current/source-connector/usage-examples/copy-existing-data/#std-label-source-usage-example-copy-existing-data

