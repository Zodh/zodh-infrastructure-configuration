data "aws_iam_role" "labrole" {
  name = "LabRole"
}

data "aws_eks_cluster_auth" "zodh-cluster" {
  name = aws_eks_cluster.zodh_cluster.name
}