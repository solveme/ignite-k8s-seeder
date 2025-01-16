#!/usr/bin/env bash

# Folder with cluster YAMLs would be created in the script directory 
CLUSTERS_DIR="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"

if [[ -h $0 ]]; then
    SEEDER_DIR="$(dirname $(readlink $0))"
else
    SEEDER_DIR="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
fi

TEMPLATE_DIR="${SEEDER_DIR}/templates"


function print_help() {
    echo "$0 CLUSTER_NAME [-i IMAGE] [-n NAMESPACE] [-b] [-w] [-d]"
}


if [[ $# == 0 || $1 == -* ]]; then
    if [[ $1 != "-h" && $1 != "--help" ]]; then
        echo "Missing cluster name"
    fi

    print_help
    exit 0
fi

export CLUSTER="$1"

shift
while [[ $# -gt 0 ]]; do
    opt="$1";
    shift
    case "$opt" in
        -i | --image)
            IMAGE0="$1"
            shift
            ;;
        -n | --namespace)
            NAMESPACE="$1"
            shift
            ;;
        -b | --bootstrap)
            BOOTSTRAP=true
            ;;
        -w | --wipe)
            WIPE=true
            ;;
        -d | --deploy)
            DEPLOY=true
            ;;
        -h | --help)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown option: $opt"
            print_help
            ;;
   esac
done

if [[ $IMAGE0 =~ .*(8.[8,9].[1-9][0-9]) ]]; then
    IMAGE0="gridgain/ultimate:${BASH_REMATCH[1]}-openjdk11-slim"
fi

if [[ $IMAGE0 =~ .*(2.[1-9][0-9].[1-9][0-9]) ]]; then
    IMAGE0="apacheignite/ignite:${BASH_REMATCH[1]}"
fi


ENVSBST="envsubst "$(cat ${SEEDER_DIR}/vars.txt)""

# Variables that wil lbe used for template interpolation, must be consistent with vars.txt
export IMAGE="${IMAGE0:-apacheignite/ignite:2.17.0}"
export NAMESPACE="${NAMESPACE:-playground}"

export APP="ignite"
export DISCOVERY_SERVICE="${APP}-hl-svc"  
export ACCOUNT="ignite-account"
export CLUSTER_ROLE="ignite-role"
export CLUSTER_ROLE_BIND="ignite-role-binding"
export CONFIG_MAP="gg-config"


TARGET_DIR=${CLUSTER}
[[ ! -d ${TARGET_DIR} ]] && mkdir -p ${TARGET_DIR}

CFG_DIR="${TARGET_DIR}/configs"
if [[ ! -d ${CFG_DIR} ]]; then
    mkdir -p ${CFG_DIR}
    cp /etc/gridgain/ggue.license.xml ${CFG_DIR}/gg.license.xml
fi


if [[ $BOOTSTRAP == "true" ]]; then
    echo "Bootstrap k8s cluster configs using >>  ${IMAGE}"

    # Yamls
    for y in ${TEMPLATE_DIR}/*.yaml; do
        cat ${y} | envsubst > ${TARGET_DIR}/$(basename ${y})
    done

    # Configs that require interpolation
    for c in ${TEMPLATE_DIR}/configs/*.*; do
        cat ${c} | envsubst "$(cat ${SEEDER_DIR}/vars.txt)" > ${CFG_DIR}/$(basename ${c})
    done

    cat ${TEMPLATE_DIR}/Makefile | envsubst > ${TARGET_DIR}/Makefile
fi

if [[ $WIPE == "true" ]]; then
    kubectl delete -n ${NAMESPACE} statefulset ${CLUSTER}
    kubectl delete clusterrolebinding ${CLUSTER_ROLE_BIND}
    kubectl delete clusterrole ${CLUSTER_ROLE}
    kubectl delete namespace ${NAMESPACE}
    sleep 1
fi

if [[ $DEPLOY == "true" ]]; then
    kubectl create namespace ${NAMESPACE}
    kubectl -n ${NAMESPACE} create sa ${ACCOUNT}
    kubectl -n ${NAMESPACE} create configmap ${CONFIG_MAP} --from-file=${TARGET_DIR}/configs/

    kubectl create -f ${TARGET_DIR}/svc.headless.yaml
    kubectl create -f ${TARGET_DIR}/svc.load_balancer.yaml
    kubectl create -f ${TARGET_DIR}/cluster-role.yaml
    kubectl create -f ${TARGET_DIR}/servers.sts.yaml
fi



