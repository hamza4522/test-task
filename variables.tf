variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "web-app"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-west-2)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "public_key_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/web-app-key.pub"
}

variable "ebs_volume_size" {
  description = "Size of the EBS volume in GB"
  type        = number
  default     = 10
}

variable "ingress_ports" {
  description = "List of ingress ports and their configurations"
  type = list(object({
    port = number
  }))
  default = [
    { port = 80 },
    { port = 443 },
    { port = 22 }
  ]
}
