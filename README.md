# Kargo demo setup

## Requirements
- Kustomize installed
- Helm installed
- Kind installed


## Setup
- Fork this repo to your own
- Create a Github PAT token if you don't already have one
- Save your github pat token to your macos keychain
    ```shell
    security add-generic-password -s "ghcr-pat" -a "<ACCOUNT_NAME>" -w "<PAT_TOKEN_VALUE"
    ```
  - This will be utilized by a kustomize plugin to generate a K8s secret in the kind cluster to allow Kargo to communicate with your repo and create commits
- Run:
  ```shell
  ./create-kustomize-generator.sh
  ```
  - This will create a custom plugin that will help generate a custom secret in a Kargo project namespace to be able to access a github repo
- Run:
  ```shell
  ./start-cluster.sh
  ```
  - This will startup a kind cluster and install:
    - ArgoCD
      - patch ArgoCD to allow LoadRestrictionsNone and enable-helm as buildOptions
    - Kargo
    - cert-manager
    - Argo Rollouts
  - ArgoCD will be available at: https://localhost:31443
  - Kargo will be available at: https://localhost:31444
- Add Argo applications for all clusters to the argocd namespace:
  ```shell
  cat argo/application.yml | kubectl apply -f -
  ```
- Add a desired pipeline to Kargo:
  ```shell
  kustomize build kargo/<pipeline_name>/ --load-restrictor LoadRestrictionsNone --enable-helm --enable-alpha-plugins | kubectl apply -f -
  ```
