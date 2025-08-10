Networking Layer
1. VPC
`
resource "aws_vpc" "capproject_vpc" {
    cidr_block = "10.0.0.0/16"

  tags = {
    Name = "capproject-vpc"
  }
}
`
Creates a Virtual Private Cloud to isolate all EKS resources. CIDR block 10.0.0.0/16 allows ~65,536 private IPs.

2. Subnets
resource "aws_subnet" "capproject_subnet" {
  count = 2
  vpc_id                  = aws_vpc.capproject_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.capproject_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "capproject-subnet-${count.index}"
  }
}
Creates two subnets in separate Availability Zones (ap-south-1a and ap-south-1b) for high availability. Public IP mapping is enabled so EC2 nodes can be accessed over the internet.

3. Internet Gateway & Route Table

   resource "aws_internet_gateway" "capproject_igw" {
  vpc_id = aws_vpc.capproject_vpc.id

  tags = {
    Name = "capproject-igw"
  }
}
An Internet Gateway allows resources in public subnets to reach the internet.
resource "aws_route_table" "capproject_route_table" {
  vpc_id = aws_vpc.capproject_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.capproject_igw.id
  }

  tags = {
    Name = "capproject-route-table"
  }
}
Creates a route table directing all outbound traffic to the Internet Gateway.

4. Route Table Association
   resource "aws_route_table_association" "capproject_association" {
  count          = 2
  subnet_id      = aws_subnet.capproject_subnet[count.index].id
  route_table_id = aws_route_table.capproject_route_table.id
}
Associates each subnet with the route table so that resources in these subnets can access the internet.


Security
Cluster Security Group
resource "aws_security_group" "capproject_cluster_sg" {
  vpc_id = aws_vpc.capproject_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "capproject-cluster-sg"
  }
}
Allows all outbound traffic from the EKS control plane.
Node Security Group
resource "aws_security_group" "capproject_node_sg" {
  vpc_id = aws_vpc.capproject_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "capproject-node-sg"
  }
}
Allows all inbound and outbound traffic to/from worker nodes.

EKS Cluster
resource "aws_eks_cluster" "capproject" {
  name     = "capproject-cluster"
  role_arn = aws_iam_role.capproject_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.capproject_subnet[*].id
    security_group_ids = [aws_security_group.capproject_cluster_sg.id]
  }
}
Creates the EKS control plane. AWS manages the master nodes; you manage worker nodes.

EKS Add-on (EBS CSI Driver)

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.capproject.name
  addon_name      = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}
Installs the Amazon EBS CSI driver to allow Kubernetes to use EBS volumes for persistent storage.

EKS Node Group
resource "aws_eks_node_group" "capproject" {
  cluster_name    = aws_eks_cluster.capproject.name
  node_group_name = "capproject-node-group"
  node_role_arn   = aws_iam_role.capproject_node_group_role.arn
  subnet_ids      = aws_subnet.capproject_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.medium"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.capproject_node_sg.id]
  }
}

Defines three worker nodes in the cluster using EC2 instances (t2.medium). Enables SSH access using an existing key pair.

🛡 IAM Roles & Policies
Cluster Role – Grants EKS control plane the required permissions.

Node Group Role – Grants worker nodes access to EKS, networking, ECR, and EBS.


Outputs
These output variables help retrieve important IDs after deployment:

Cluster ID

Node Group ID

VPC ID

Subnet IDs


EKS Terraform Flow Diagram
Here’s a Mermaid diagram you can paste directly into your .md file to visualize the flow:
flowchart TD
    A[Start Terraform Apply] --> B[Configure AWS Provider]
    B --> C[Create VPC using VPC Module]
    C --> D[Create Public & Private Subnets]
    D --> E[Setup NAT Gateway & DNS Hostnames]
    E --> F[Provision EKS Cluster using EKS Module]
    F --> G[Create Worker Nodes in Private Subnets]
    G --> H[Configure aws-auth for Node Access]
    H --> I[Output Cluster Endpoint & Security Group ID]
    I --> J[Use kubectl to Access Cluster]




<img src="https://sdmntprnorthcentralus.oaiusercontent.com/files/00000000-fbec-622f-8f2c-7c1ed5752178/raw?se=2025-08-10T08%3A43%3A24Z&amp;sp=r&amp;sv=2024-08-04&amp;sr=b&amp;scid=056bfb37-d0ba-5c55-b4a7-41eea1dec7c7&amp;skoid=9ccea605-1409-4478-82eb-9c83b25dc1b0&amp;sktid=a48cca56-e6da-484e-a814-9c849652bcb3&amp;skt=2025-08-10T06%3A22%3A59Z&amp;ske=2025-08-11T06%3A22%3A59Z&amp;sks=b&amp;skv=2024-08-04&amp;sig=jupkNmg3/hMgkzqHbwBK/920noWNmjX7zgN2wVE4BoY%3D"/><img width="1024" height="1536" alt="image" src="https://github.com/user-attachments/assets/8312ab80-0b39-4a7f-9abf-73f808415826" />
