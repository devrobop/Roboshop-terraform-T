resource "null_resource" "kube-config" {
  depends_on = [aws_eks_node_group.main]

  provisioner "local-exec" {
    command =<<EOF
aws eks update-kubeconfig --name ${var.env}-eks
EOF    
    
  }
}

# External secrets
resource "helm_release" "external-secrets" {

  depends_on = [null_resource.kube-config]  
  
  name       = "external-secrets"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-secrets"
  namespace  = "kube-system"


}