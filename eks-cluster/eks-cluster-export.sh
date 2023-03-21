echo -e "to get the kube-config to access the EKS cluster"

aws eks --region us-east-1 update-kubeconfig --name eks-kafka-connect
