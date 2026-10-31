terraform {
  required_version = ">= 1.5.0"

  backend "local" {
    path = "/home/aiko/.terraform-state/k3s-gitops.tfstate"
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "6.7.11"

  set {
    name  = "server.service.type"
    value = "NodePort"
  }
}

resource "helm_release" "argocd_apps" {
  depends_on = [helm_release.argocd]
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "2.0.0"

  values = [
    <<-EOT
    applications:
      nginx-demo:
        namespace: argocd
        project: default
        source:
          repoURL: https://github.com/gerrysereal/k3s-gitops-stategraph.git
          targetRevision: HEAD
          path: apps/nginx-demo
        destination:
          server: https://kubernetes.default.svc
          namespace: default
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
      ecommerce:
        namespace: argocd
        project: default
        source:
          repoURL: https://github.com/gerrysereal/k3s-gitops-stategraph.git
          targetRevision: HEAD
          path: apps/ecommerce
        destination:
          server: https://kubernetes.default.svc
          namespace: default
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
    EOT
  ]
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = kubernetes_namespace.vault.metadata[0].name
  version    = "0.28.0"

  set {
    name  = "server.dev.enabled"
    value = "true"
  }
  set {
    name  = "server.dev.devRootToken"
    value = "root-token-wsl"
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  version          = "0.9.19"
}
