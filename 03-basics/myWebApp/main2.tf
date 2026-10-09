terraform {
  required_providers {
    aws = {

      source  = "hashicorp/aws"
      version = "~> 6.0"

    }
  }
}


data "aws_availability_zones" "available" {
  state = "available"
}

provider "aws" {

  region = "ap-southeast-2"
}

resource "aws_vpc" "myVPC" {

  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "myTerraformVPC"
  }

}

resource "aws_subnet" "mySubnet1" {

  vpc_id                  = aws_vpc.myVPC.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

}

resource "aws_subnet" "mySubnet2" {

  vpc_id                  = aws_vpc.myVPC.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myVPC.id

}
resource "aws_route_table" "PublicRT" {
  vpc_id = aws_vpc.myVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "PublicRTassociation1" {
  subnet_id      = aws_subnet.mySubnet1.id
  route_table_id = aws_route_table.PublicRT.id
}

resource "aws_route_table_association" "PublicRTassociation2" {
  subnet_id      = aws_subnet.mySubnet2.id
  route_table_id = aws_route_table.PublicRT.id
}



resource "aws_instance" "myInstance1" {

  ami                    = "ami-06259b63260eddc13"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.InstanceSG.id]
  subnet_id              = aws_subnet.mySubnet1.id


  tags = {
    Name = "myInstance1"
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World 1" > index.html
              python3 -m http.server 8080 &
              EOF
}

resource "aws_instance" "myInstance2" {

  ami                    = "ami-06259b63260eddc13"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.InstanceSG.id]
  subnet_id              = aws_subnet.mySubnet2.id

  tags = {
    Name = "myInstance2"
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World 2" > index.html
              python3 -m http.server 8080 &
              EOF
}

resource "aws_security_group" "albSG" {
  name   = "albSG"
  vpc_id = aws_vpc.myVPC.id

  tags = { Name = "albSG" }

}

resource "aws_security_group_rule" "albInRule" {

  type              = "ingress"
  security_group_id = aws_security_group.albSG.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "albOutRule" {

  type                     = "egress"
  security_group_id        = aws_security_group.albSG.id
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.InstanceSG.id
}

resource "aws_security_group" "InstanceSG" {
  name   = "InstanceSG"
  vpc_id = aws_vpc.myVPC.id

  tags = { Name = "InstanceSG" }

}

resource "aws_security_group_rule" "InstanceSGRule" {

  type                     = "ingress"
  security_group_id        = aws_security_group.InstanceSG.id
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.albSG.id
}
