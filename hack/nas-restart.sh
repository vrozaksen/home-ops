#!/usr/bin/env bash
kubectl get deployments --all-namespaces -l nfsMount=true -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name" --no-headers  | awk '{print "kubectl rollout restart deployment/"$2" -n "$1} ' | sh
