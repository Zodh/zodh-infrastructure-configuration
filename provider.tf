provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = aws_eks_cluster.zodh_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.zodh_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.zodh-cluster.token
}