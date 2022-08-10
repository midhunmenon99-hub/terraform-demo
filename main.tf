terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}


resource "aws_instance" "app_server" {
    ami           = "ami-052efd3df9dad4825"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.app_server_subnet_public.id}"
	#security_groups = ["default"]
	vpc_security_group_ids = [aws_security_group.app_server_sg.id]
	key_name = "ubuntu_private_key"
	
	provisioner "remote-exec"{
		inline = [
			"sudo apt-get update",
			"sudo apt-get install apache2 -y",
			"sudo systemctl start apache2"
		]
	}

	connection {
		type = "ssh"
		user = "ubuntu"
		private_key = file("ubuntu_private_key.pem")
		host = "${self.public_ip}"
	}
	
    tags = {
      Name = "app_server"
    }
}


resource "aws_vpc" "app_server_vpc" {
    cidr_block = "80.0.0.0/16"
    enable_dns_support = "true" #gives you an internal domain name
    enable_dns_hostnames = "true" #gives you an internal host name
    enable_classiclink = "false"
    instance_tenancy = "default" 
	#security_groups = ["${aws_security_group.app_server_sg.id}"]
	#security_groups = ["app_server_sg"]
    
    tags =  {
        Name = "app_server_vpc"
    }
}

resource "aws_subnet" "app_server_subnet_public" {
    vpc_id = "${aws_vpc.app_server_vpc.id}"
    cidr_block = "80.0.0.0/24"
    map_public_ip_on_launch = "true" //it makes this a public subnet
    availability_zone = "us-east-1a"
    tags = {
        Name = "app_server_subnet_public"
    }
}


resource "aws_security_group" "app_server_sg" {
    vpc_id = "${aws_vpc.app_server_vpc.id}"
	#name = "app_server_sg"
	#description = "security_group"

    ingress {
     protocol  = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
     from_port = 22
     to_port   = 22
    }

    ingress {
     protocol  = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
     from_port = 80
     to_port   = 80
    }
  
    egress {
     from_port   = 0
     to_port     = 0
     protocol    = "-1"
     cidr_blocks = ["0.0.0.0/0"]
    }
  
    tags = {
        Name = "app_server_sg"
    }
}

resource "aws_internet_gateway" "app_server_igw" {
  vpc_id = aws_vpc.app_server_vpc.id

  tags = {
    Name = "app_server_igw"
  }
}

resource "aws_route_table" "app_server_rt" {
  vpc_id = aws_vpc.app_server_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_server_igw.id
  }


  tags = {
    Name = "app_server_rt"
  }
}

resource "aws_route_table_association" "app_server_route_subnet_association" {
  subnet_id      = aws_subnet.app_server_subnet_public.id
  route_table_id = aws_route_table.app_server_rt.id
}





