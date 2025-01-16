.PHONY: help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

get-shell: ## Get shell of first pod
	kubectl -n ${NAMESPACE} exec --stdin --tty ${CLUSTER}-0 -- /bin/bash

restart: ## Restart stateful set
	kubectl -n ${NAMESPACE} rollout restart statefulset ${CLUSTER}.

deploy-services: ## Deploy additional services
	kubectl -n ${NAMESPACE} create -f svc.cluster_ip.yaml
	kubectl -n ${NAMESPACE} create -f svc.node_port.yaml
