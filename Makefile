DOCKERFILE ?= Dockerfile ## Which Dockerfile to use for build
NAME := k8s-flexvol-imagevol
KUBE_NAMESPACE ?= "default"
KUBECTL_VERSION ?= 1.14.1
DRIVER_NAMESPACE ?= kube-system
CI_REGISTRY ?= docker.io
CI_REPOSITORY ?= piersharding
IMAGE ?= $(CI_REPOSITORY)/$(NAME)
TAG ?= latest
RUNTIME_ENDPOINT ?= /run/containerd/containerd.sock
DEBUG ?= false

.PHONY: k8s show deploy delete logs describe namespace test clean help
.DEFAULT_GOAL := help

# define overrides for above variables in here
-include PrivateRules.mak

k8s: ## Which kubernetes are we connected to
	@echo "Kubernetes cluster-info:"
	@kubectl cluster-info
	@echo ""
	@echo "kubectl version:"
	@kubectl version
	@echo "kustomize version:"
	@kustomize version

clean: ## remove deployment DaemonSet and temp vars
	$(MAKE) delete || true
	rm -rf ./deploy/overlays/envsub/fix-params.yaml

image: ## build deployment image
	docker build \
	  -t $(NAME):latest -f $(DOCKERFILE) .

push: image ## push deployment image
	docker tag $(NAME):latest $(IMAGE):$(TAG)
	docker push $(IMAGE):$(TAG)

envsubst:
	RUNTIME_ENDPOINT=$(RUNTIME_ENDPOINT) \
	DEBUG=$(DEBUG) \
	 envsubst < ./deploy/overlays/envsub/fix-params.yaml.in >./deploy/overlays/envsub/fix-params.yaml

show: k8s envsubst ## show deployment of imagevol Flexvolume
	kustomize build ./deploy/overlays/envsub

deploy: k8s envsubst ## deploy imagevol Flexvolume
	kustomize build ./deploy/overlays/envsub | kubectl -n $(DRIVER_NAMESPACE) apply -f -

delete: k8s envsubst ## delete deployment of imagevol Flexvolume
	kustomize build ./deploy/overlays/envsub | kubectl -n $(DRIVER_NAMESPACE) delete --wait=true -f -

logs: ## deployment logs
	kubectl get pods -l \
	app=k8s-image-vol \
	-n $(DRIVER_NAMESPACE)
	kubectl logs -l \
	app=k8s-image-vol \
	-n $(DRIVER_NAMESPACE)

describe: ## describe Pods executed from deployment
	@for i in `kubectl -n $(DRIVER_NAMESPACE) get pods -l app=k8s-image-vol -o=name`; \
	do echo "---------------------------------------------------"; \
	echo "Describe for $${i}"; \
	echo kubectl -n $(DRIVER_NAMESPACE) describe $${i}; \
	echo "---------------------------------------------------"; \
	kubectl -n $(DRIVER_NAMESPACE) describe $${i}; \
	echo "---------------------------------------------------"; \
	echo ""; echo ""; echo ""; \
	done

test_image: ## build test image
	docker build \
	  -t $(NAME)-test:latest -f Dockerfile.test .

push_test: test_image ## push test image
	docker tag $(NAME)-test:latest $(IMAGE)-test:$(TAG)
	docker push $(IMAGE)-test:$(TAG)

test: push_test namespace ## deploy test
	kubectl apply -f tests/mount-test.yaml -n $(KUBE_NAMESPACE)

test-results:  ## curl test
	kubectl wait --for=condition=available deployment.v1.apps/nginx-deployment1 --timeout=180s
	SVC_IP=$$(kubectl -n $(KUBE_NAMESPACE) get svc nginx1 -o json | jq -r '.spec.clusterIP') && \
	curl http://$${SVC_IP}
	kubectl wait --for=condition=available deployment.v1.apps/nginx-deployment2 --timeout=180s
	SVC_IP=$$(kubectl -n $(KUBE_NAMESPACE) get svc nginx2 -o json | jq -r '.spec.clusterIP') && \
	curl http://$${SVC_IP}

test-clean:  ## clean down test
	kubectl delete -f tests/mount-test.yaml -n $(KUBE_NAMESPACE) || true
	sleep 1

cleanall: test-clean clean  ## Clean all

redeploy: cleanall push deploy  ## redeploy operator

namespace: ## create the kubernetes namespace
	kubectl describe namespace $(KUBE_NAMESPACE) || kubectl create namespace $(KUBE_NAMESPACE)

delete_namespace: ## delete the kubernetes namespace
	@if [ "default" == "$(KUBE_NAMESPACE)" ] || [ "kube-system" == "$(KUBE_NAMESPACE)" ]; then \
	echo "You cannot delete Namespace: $(KUBE_NAMESPACE)"; \
	exit 1; \
	else \
	kubectl describe namespace $(KUBE_NAMESPACE) && kubectl delete namespace $(KUBE_NAMESPACE); \
	fi

kubectl_dependencies: ## Utility target to install kubectl dependencies
	@([ -n "$(KUBE_CONFIG_BASE64)" ] && [ -n "$(KUBECONFIG)" ]) || (echo "unset variables [KUBE_CONFIG_BASE64/KUBECONFIG] - abort!"; exit 1)
	@which kubectl ; rc=$$?; \
	if [[ $$rc != 0 ]]; then \
		curl -L -o /usr/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/$(KUBERNETES_VERSION)/bin/linux/amd64/kubectl"; \
		chmod +x /usr/bin/kubectl; \
		mkdir -p /etc/deploy; \
		echo $(KUBE_CONFIG_BASE64) | base64 -d > $(KUBECONFIG); \
	fi
	@echo -e "\nkubectl client version:"
	@kubectl version --client
	@echo -e "\nkubectl config view:"
	@kubectl config view
	@echo -e "\nkubectl config get-contexts:"
	@kubectl config get-contexts
	@echo -e "\nkubectl version:"
	@kubectl version

help:  ## show this help.
	@echo "make targets:"
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ": .*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo ""; echo "make vars (+defaults):"
	@grep -E '^[0-9a-zA-Z_-]+ \?=.*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = " \\?\\= "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
