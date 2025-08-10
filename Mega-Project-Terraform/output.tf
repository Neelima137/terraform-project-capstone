output "cluster_id" {
  value = aws_eks_cluster.capproject.id
}

output "node_group_id" {
  value = aws_eks_node_group.capproject.id
}

output "vpc_id" {
  value = aws_vpc.capproject_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.capproject_subnet[*].id
}
