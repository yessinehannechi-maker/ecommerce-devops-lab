# 1. Définition du fournisseur AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Obligatoire pour AWS Academy Learner Lab
}

# 2. Création du VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# 3. Création de la passerelle Internet (Internet Gateway)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# 4. Création des sous-réseaux Publics (pour l'Application Load Balancer)
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

# 5. Tables de routage pour le réseau public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# 6. Groupe de Sécurité pour le Load Balancer (ALB)
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Permettre le trafic HTTP/HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. Groupe de Sécurité pour les instances EC2 (Web)
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  # Autoriser SSH depuis partout pour GitHub Actions et Ansible
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Autoriser le port 80 en provenance du Load Balancer
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 8. Application Load Balancer (ALB)
resource "aws_lb" "web_alb" {
  name               = "ecommerce-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "tg_web" {
  name     = "tg-webapps"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_web.arn
  }
}

# 9. Récupération automatique de l'image Amazon Linux 2 officielle
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# 10. Création des deux Instances EC2
# Configuration adaptée pour le Learner Lab d'AWS Academy (Utilisation du LabInstanceProfile)
resource "aws_instance" "web_1" {
  ami                  = data.aws_ami.amazon_linux_2.id
  instance_type        = "t3.micro"
  subnet_id            = aws_subnet.public_1.id 
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name             = "vockey" # Nom de clé obligatoire AWS Academy

  iam_instance_profile = "LabInstanceProfile" # Profil IAM requis en Lab étudiant

  tags = {
    Name = "EC2-Web-1"
  }
}

resource "aws_instance" "web_2" {
  ami                  = data.aws_ami.amazon_linux_2.id
  instance_type        = "t3.micro"
  subnet_id            = aws_subnet.public_2.id 
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name             = "vockey" # Nom de clé obligatoire AWS Academy

  iam_instance_profile = "LabInstanceProfile" # Profil IAM requis en Lab étudiant

  tags = {
    Name = "EC2-Web-2"
  }
}

# Liaison des instances au Target Group de l'ALB
resource "aws_lb_target_group_attachment" "web_1" {
  target_group_arn = aws_lb_target_group.tg_web.arn
  target_id        = aws_instance.web_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_2" {
  target_group_arn = aws_lb_target_group.tg_web.arn
  target_id        = aws_instance.web_2.id
  port             = 80
}
