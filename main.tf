provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
  tags = {
    Name  = "${var.app_name}-subnet"
    owner = "hamza ali"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name  = "${var.app_name}-igw"
    owner = "hamza ali"

  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name  = "${var.app_name}-route-table"
    owner = "hamza ali"

  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.app_name}-sg"

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.app_name}-sg"
    owner = "hamza ali"

  }
}

# Key Pair
resource "aws_key_pair" "web_key" {
  key_name   = "${var.app_name}-key"
  public_key = file(var.public_key_path)
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.web_key.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              # Install Node.js
              curl -sL https://rpm.nodesource.com/setup_16.x | bash -
              yum install -y nodejs
              # Install PM2 globally
              npm install -g pm2
              # Create a simple Node.js app
              mkdir /app
              cd /app
              npm init -y
              npm install express
              cat << 'EOL' > /app/server.js
              const express = require('express');
              const app = express();
              app.get('/', (req, res) => {
                res.send('<h1>Welcome to the Node.js Web App</h1>');
              });
              app.listen(3000, () => {
                console.log('Server running on port 3000');
              });
              EOL
              # Start the Node.js app with PM2
              cd /app
              pm2 start server.js --name node-app
              pm2 save
              pm2 startup systemd
              # Install and configure Nginx as reverse proxy
              yum install -y nginx
              cat << 'EOL' > /etc/nginx/conf.d/node-app.conf
              server {
                  listen 80;
                  server_name _;
                  location / {
                      proxy_pass http://localhost:3000;
                      proxy_http_version 1.1;
                      proxy_set_header Upgrade $http_upgrade;
                      proxy_set_header Connection 'upgrade';
                      proxy_set_header Host $host;
                      proxy_cache_bypass $http_upgrade;
                  }
              }
              EOL
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    Name  = "${var.app_name}-server"
    owner = "hamza ali"

  }
}

resource "aws_ebs_volume" "storage" {
  availability_zone = "${var.region}a"
  size              = var.ebs_volume_size
  tags = {
    Name = "${var.app_name}-storage"
  }
}

# Attach EBS Volume to EC2
resource "aws_volume_attachment" "web_storage_attachment" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.storage.id
  instance_id = aws_instance.web.id
}