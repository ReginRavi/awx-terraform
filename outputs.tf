output "admin_password_command" {
  value = "kubectl -n ${var.namespace} get secret awx-demo-admin-password -o jsonpath=\"{.data.password}\" | base64 -d; echo"
}

output "web_access_tip" {
  value = <<EOT
After the AWX pods are Ready, port-forward to access the UI:

  kubectl -n ${var.namespace} port-forward svc/awx-demo-service 8043:80

Then open:  http://localhost:8043
Login user: admin
Password:   (run the command from 'admin_password_command' output)
EOT
}