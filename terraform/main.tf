# 1. AWS Provider Initialization
provider "aws" {
  region = "ap-south-1"
}

# 2. VPC Setup
resource "aws_vpc" "mern_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

# 3. Subnets (Public for Web, Private for DB)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.mern_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.mern_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
}

# 4. Internet Gateway & NAT Gateway (for internet access)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mern_vpc.id
}

resource "aws_eip" "nat_eip" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
}

# 5. Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.mern_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.mern_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# 6. Security Groups
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.mern_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Change to your local public IP for better security
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3001
    to_port     = 3001
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

resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.mern_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Only accessible from Web Server
  }
  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # MongoDB port
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. EC2 Instances Deployment
resource "aws_instance" "web_server" {
  ami                    = "ami-007020fd9c84e18c7" # Example Ubuntu 22.04 AMI (verify for your region)
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "mernapp-terraform-key" # Must exist in your AWS EC2 key-pairs console
  tags = { Name = "MERN-Web-Server" }
}

resource "aws_instance" "db_server" {
  ami                    = "ami-007020fd9c84e18c7" # Example Ubuntu 22.04 AMI (verify for your region)
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = "mernapp-terraform-key"
  tags = { Name = "MERN-DB-Server" }
}
