#!/bin/bash

Clusters=(AKS-Alfa AKS-Bravo AKS-Charlie AKS-Delta AKS-Echo AKS-Foxtrot)
Location="westeurope"
sub1="i"  # Gyakorlat.1
sub2="j"  # Gyakorlat.2

set_subscription() {
  local subscription_id=$1
  echo "Setting subscription: $subscription_id"
  az account set --subscription "$subscription_id"
}

create_resource_group() {
  local rg_name=$1
  local location=$2
  if az group show --name "$rg_name" &>/dev/null; then
    echo "Resource group $rg_name already exists. Skipping creation."
  else
    echo "Creating resource group: $rg_name"
    az group create --name "$rg_name" --location "$location"
  fi
}

delete_resource_group() {
  local rg_name=$1
  echo "Deleting resource group: $rg_name"
  az group delete --name "$rg_name" --yes --no-wait
}

create_cluster() {
  local cluster_name=$1
  local subscription_id=$2
  local location=$3

  set_subscription "$subscription_id"
  create_resource_group "$cluster_name" "$location"
  echo "Creating cluster: $cluster_name"
  az aks create \
    --name "$cluster_name" \
    --resource-group "$cluster_name" \
    --auto-upgrade-channel "none" \
    --enable-cluster-autoscaler \
    --min-count 1 \
    --max-count 3 \
    --node-count 1 \
    --node-os-upgrade-channel "none" \
    --node-vm-size "Standard_B2s" \
    --network-plugin kubenet \
    --no-ssh-key \
    --no-wait
}

manage_cluster_state() {
  local cluster_name=$1
  local subscription_id=$2
  local action=$3

  set_subscription "$subscription_id"
  if [ "$action" = "start" ]; then
    echo "Starting AKS cluster: $cluster_name"
    az aks start --name "$cluster_name" --resource-group "$cluster_name"
  elif [ "$action" = "stop" ]; then
    echo "Stopping AKS cluster: $cluster_name"
    az aks stop --name "$cluster_name" --resource-group "$cluster_name"
  else
    echo "Unknown action: $action"
    return 1
  fi
}

delete_cluster() {
  local cluster_name=$1
  local subscription_id=$2

  set_subscription "$subscription_id"
  echo "Deleting AKS cluster: $cluster_name"
  az aks delete --name "$cluster_name" --resource-group "$cluster_name" --yes --no-wait
  delete_resource_group "$cluster_name"
}

cluster_status() {
  local cluster_name=$1
  local subscription_id=$2

  set_subscription "$subscription_id"
  echo "Status for AKS cluster: $cluster_name"
  az aks show --name "$cluster_name" --resource-group "$cluster_name" --query "{name:name, provisioningState:provisioningState, powerState:powerState.state}" --output table
}


usage() {
  echo "Usage: $0 [create|stop|start|delete|status]"
  exit 1
}

if [ $# -ne 1 ]; then
  usage
fi

iterate_over_clusters() {
  local action_func=$1
  local location_arg=$2

  for i in {0..2}; do
    if [ -n "$location_arg" ]; then
      $action_func "${Clusters[$i]}" "$sub1" "$location_arg"
    else
      $action_func "${Clusters[$i]}" "$sub1"
    fi
  done
  for i in {3..5}; do
    if [ -n "$location_arg" ]; then
      $action_func "${Clusters[$i]}" "$sub2" "$location_arg"
    else
      $action_func "${Clusters[$i]}" "$sub2"
    fi
  done
}

case "$1" in
  create)
    iterate_over_clusters create_cluster "$Location"
    ;;
  stop)
    iterate_over_clusters manage_cluster_state "stop"
    ;;
  start)
    iterate_over_clusters manage_cluster_state "start"
    ;;
  delete)
    iterate_over_clusters delete_cluster
    ;;
  status)
    iterate_over_clusters cluster_status
    ;;
  *)
    usage
    ;;
esac
