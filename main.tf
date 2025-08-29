provider "kind" {}

resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true

  node_image = "kindest/node:${var.k8s_version}"
}
resource "null_resource" "select_context" {
  provisioner "local-exec" {
    command = "kubectl config use-context kind-${var.cluster_name}"
  }
  depends_on = [kind_cluster.this]
}

resource "null_resource" "wait_api" {
  provisioner "local-exec" {
    # wait until the API answers
    command = "bash -lc 'for i in {1..60}; do kubectl get nodes && exit 0; sleep 2; done; echo timeout && exit 1'"
  }
  depends_on = [null_resource.select_context]
}

# make namespace creation wait on the API being ready
resource "kubernetes_namespace" "awx" {
  metadata { name = var.namespace }
  depends_on = [null_resource.wait_api]
}
data "external" "kubeconfig_path" {
  program = ["bash", "-lc", <<EOT
set -euo pipefail
echo "{\"home\":\"$HOME\"}"
EOT
  ]
}

provider "kubernetes" {
  config_path = "${data.external.kubeconfig_path.result.home}/.kube/config"
}

provider "kubectl" {
  load_config_file = true
  config_path      = "${data.external.kubeconfig_path.result.home}/.kube/config"
}

resource "null_resource" "awx_operator" {
  triggers = {
    operator_version = var.operator_version
    namespace        = var.namespace
    cluster          = kind_cluster.this.name
  }

  provisioner "local-exec" {
    command = "kubectl apply -k https://github.com/ansible/awx-operator/config/default?ref=${var.operator_version} -n ${var.namespace}"
  }

  depends_on = [
    kubernetes_namespace.awx
  ]
}

resource "kubectl_manifest" "awx_cr" {
  yaml_body = <<-YAML
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-demo
  namespace: ${var.namespace}
spec:
  service_type: NodePort
  ingress_type: none
YAML
  depends_on = [null_resource.awx_operator]
}

resource "null_resource" "wait_awx" {
  provisioner "local-exec" {
    command = "kubectl -n ${var.namespace} wait --for=condition=available --timeout=300s deployment/awx-operator-controller-manager"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Destroying...'"
  }

  depends_on = [null_resource.awx_operator]
}

resource "null_resource" "wait_awx_instance" {
  provisioner "local-exec" {
    command = "kubectl -n ${var.namespace} rollout status deployment/awx-demo --timeout=600s || true"
  }
  depends_on = [kubectl_manifest.awx_cr]
}


