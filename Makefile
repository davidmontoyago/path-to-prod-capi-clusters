pre-reqs:
	# kind
	$(GOCMD) get sigs.k8s.io/kind@v0.7.0
	
	# clusterawsadm
	# cd $(HOME)/bin && \
	# 	 curl -LO https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v0.4.8/clusterawsadm-darwin-amd64 && \
	# 	 chmod 700 ./clusterawsadm-darwin-amd64 && \
	# 	 ln -sf $(HOME)/bin/clusterawsadm-darwin-amd64 $(HOME)/bin/clusterawsadm


#
# get cluster api and bootstrap provider manifests
# 
capi-manifests:
	# cluster api 
	curl -L -o ./manifests/management/cluster-api-components.yaml https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.2.9/cluster-api-components.yaml
	curl -L -o ./manifests/management/bootstrap-components.yaml https://github.com/kubernetes-sigs/cluster-api-bootstrap-provider-kubeadm/releases/download/v0.1.5/bootstrap-components.yaml
	# cert manageer
	curl -L -o ./manifests/management/cert-manager.yaml https://github.com/jetstack/cert-manager/releases/download/v0.11.0/cert-manager.yaml

# 
# get gcp infra provider manifests
# 
gcp-provider-manifest:
	curl -L -o ./manifests/workload/capg/infrastructure-components.yaml https://github.com/kubernetes-sigs/cluster-api-provider-gcp/releases/download/v0.2.0-alpha.2/infrastructure-components.yaml

# 
# create local management cluster
# 
manager:
	kubectl apply -f manifests/management/cert-manager.yaml
	kubectl wait --for=condition=Available --timeout=300s apiservice v1beta1.webhook.cert-manager.io
	kubectl apply -f manifests/management/cluster-api-components.yaml
	kubectl apply -f manifests/management/bootstrap-components.yaml
	make gcp-provider

# 
# install gcp infra provider
# 
gcp-provider:
	cat ./manifests/management/capg/infrastructure-components.yaml \
  		| envsubst \
  		| kubectl apply -f -

#
# deploy gcp capi cluster
#
gcp-cluster:
	kubectl apply -f ./manifests/workload/gcp/capi-cluster.yaml
	make gcp-controlplane

#
# deploy gcp control plane
#
gcp-controlplane:
	kubectl apply -f ./manifests/workload/gcp/capi-controlplane.yaml
	kubectl get machines --selector cluster.x-k8s.io/control-plane

gcp-cni:
	kubectl --kubeconfig=./gcp-pathtoprod.kubeconfig apply -f ./manifests/workload/cni.yaml

#
# deploy gcp worker nodes
#
gcp-workers:
	cat ./manifests/workload/gcp/capi-worker-nodes.yaml \
		| envsubst \
		| kubectl apply -f -

gcp-kubeconfig:
	kubectl get secret capg-pathtoprod-kubeconfig -o json | jq -r .data.value | base64 -D > ./gcp-pathtoprod.kubeconfig


gcp-destroy:
	kubectl delete --ignore-not-found -f ./manifests/workload/cni.yaml
	kubectl delete --ignore-not-found -f ./manifests/workload/gcp/capi-worker-nodes.yaml
	kubectl delete --ignore-not-found -f ./manifests/workload/gcp/capi-controlplane.yaml
	kubectl delete --ignore-not-found -f ./manifests/workload/gcp/capi-cluster.yaml