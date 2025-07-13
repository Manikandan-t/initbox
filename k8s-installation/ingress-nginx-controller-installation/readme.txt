Schedule on specific node
change nodeName(kubernetes.io/hostname) in admission-job.yaml and patch-job.yaml

kubectl delete job ingress-nginx-admission-create
kubectl apply -f admission-job.yaml

kubectl delete job ingress-nginx-admission-patch
kubectl apply -f patch-job.yaml