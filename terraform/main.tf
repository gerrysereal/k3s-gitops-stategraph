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
    EOT
  ]
}
