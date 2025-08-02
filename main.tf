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


resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "${var.app_name}-ec2-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ec2_cloudwatch_policy" {
  name        = "${var.app_name}-ec2-cw-policy"
  description = "Policy for EC2 to send logs and metrics to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_cw_policy_attach" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = aws_iam_policy.ec2_cloudwatch_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.app_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name
}


resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.web_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y

              # Install CloudWatch Agent
              yum install -y amazon-cloudwatch-agent

              # Create CloudWatch Agent config file
              cat <<EOT > /opt/aws/amazon-cloudwatch-agent/bin/config.json
              {
                "agent": {
                  "metrics_collection_interval": 60,
                  "run_as_user": "root"
                },
                "metrics": {
                  "namespace": "${var.app_name}",
                  "metrics_collected": {
                    "cpu": {
                      "measurement": [
                        "cpu_usage_idle",
                        "cpu_usage_iowait",
                        "cpu_usage_user",
                        "cpu_usage_system"
                      ],
                      "metrics_collection_interval": 60,
                      "totalcpu": true
                    },
                    "mem": {
                      "measurement": [
                        "mem_used_percent"
                      ],
                      "metrics_collection_interval": 60
                    },
                    "disk": {
                      "measurement": [
                        "disk_used_percent"
                      ],
                      "metrics_collection_interval": 60,
                      "resources": [
                        "/"
                      ]
                    }
                  }
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/home/ec2-user/app/server.log",
                          "log_group_name": "${var.app_name}-app-logs",
                          "log_stream_name": "{instance_id}"
                        }
                      ]
                    }
                  }
                }
              }
              EOT

              # Start CloudWatch Agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

              # Install Node.js & PM2
              curl -sL https://rpm.nodesource.com/setup_16.x | bash -
              yum install -y nodejs
              npm install -g pm2

              # Install and configure Nginx
              yum install -y nginx
              cat << 'NGINX_CONF' > /etc/nginx/conf.d/node-app.conf
              server {
                  listen 80;
                  server_name _;

                  location / {
                      proxy_pass http://localhost:3000;
                      proxy_http_version 1.1;
                      proxy_set_header Upgrade \$http_upgrade;
                      proxy_set_header Connection 'upgrade';
                      proxy_set_header Host \$host;
                      proxy_cache_bypass \$http_upgrade;
                  }
              }
              NGINX_CONF

              systemctl start nginx
              systemctl enable nginx

              # Setup and start Node.js app with logging
              su - ec2-user << 'USER_CMDS'

              mkdir -p /home/ec2-user/app
              cd /home/ec2-user/app

              npm init -y
              npm install express

              # Create server.js with request logging to server.log
              cat << 'APP_JS' > server.js
              const fs = require('fs');
              const express = require('express');
              const app = express();

              const logStream = fs.createWriteStream('./server.log', { flags: 'a' });

              app.use((req, res, next) => {
                const logLine = `$${new Date().toISOString()} - $${req.method} $${req.url}\n`;
                logStream.write(logLine);
                next();
              });

              app.get('/', (req, res) => {
                res.send('<h1>Welcome to the Node.js Web App</h1>');
              });

              app.listen(3000, () => {
                console.log('Server running on port 3000');
              });
              APP_JS

              npm set-script start "node server.js"

              pm2 start npm --name node-app -- start
              pm2 save

              USER_CMDS
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

resource "aws_volume_attachment" "web_storage_attachment" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.storage.id
  instance_id = aws_instance.web.id
}


resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.app_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  alarm_description = "Alarm when CPU exceeds 80%"

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  alarm_actions = []
  ok_actions    = []
}
