#!/usr/bin/env bash

# Folder with cluster YAMLs would be created in the script directory 
CLUSTERS_DIR="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"

if [[ -h $0 ]]; then
    TEMPLATE_DIR="$(dirname $(readlink $0))/templates"
else
    TEMPLATE_DIR="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )/templates"
fi


function print_help() {
    echo "$0 CLUSTER_NAME [-i IMAGE] [-n NAMESPACE] [-w] [-d]"
}


if [[ $# == 0 || $1 == -* ]]; then
    echo "Missing cluster name"
    print_help
fi

export CLUSTER="$1"

shift
while [[ $# -gt 0 ]]; do
    opt="$1";
    shift
    case "$opt" in
        -i | --image)
            IMAGE="$1"
            shift
            ;;
        -n | --namespace)
            NAMESPACE="$1"
            shift
            ;;
        -w | --wipe)
            WIPE=true
            ;;
        -d | --deploy)
            DEPLOY=true
            ;;
        *)
            echo "Unknown option: $opt"
            print_help
            ;;
   esac
done

export IMAGE="${IMAGE:-apacheignite/ignite:2.14.0}"
export NAMESPACE="${NAMESPACE:-playground}"

export APP="ignite"
export SERVICE="ignite-service"  
export ACCOUNT="ignite-account"
export CLUSTER_ROLE="ignite-role"
export CLUSTER_ROLE_BIND="ignite-role-binding"
export CONFIG_MAP="ignite-config"


TARGET_DIR=${CLUSTER}
[[ ! -d ${TARGET_DIR} ]] && mkdir -p ${TARGET_DIR}


cat ${TEMPLATE_DIR}/node-config.xml | envsubst > ${TARGET_DIR}/node-config.xml
cat ${TEMPLATE_DIR}/service.yaml | envsubst > ${TARGET_DIR}/service.yaml
cat ${TEMPLATE_DIR}/cluster-role.yaml | envsubst > ${TARGET_DIR}/cluster-role.yaml
cat ${TEMPLATE_DIR}/deployment.yaml | envsubst > ${TARGET_DIR}/deployment.yaml

if [[ $WIPE == "true" ]]; then
    kubectl delete clusterrolebinding ${CLUSTER_ROLE_BIND}
    kubectl delete clusterrole ${CLUSTER_ROLE}
    kubectl delete -n ${NAMESPACE} deployment ${CLUSTER}
    kubectl delete namespace ${NAMESPACE}
    sleep 5
fi

if [[ $DEPLOY == "true" ]]; then
    kubectl create namespace ${NAMESPACE}
    kubectl create -f ${TARGET_DIR}/service.yaml
    kubectl -n ${NAMESPACE} create sa ${ACCOUNT}
    kubectl create -f ${TARGET_DIR}/cluster-role.yaml
    kubectl -n ${NAMESPACE} create configmap ${CONFIG_MAP} --from-file=${TARGET_DIR}/node-config.xml
    kubectl create -f ${TARGET_DIR}/deployment.yaml
fi



