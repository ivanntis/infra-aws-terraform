provider "aws" {
    profile = "pulse-profile"
    region  = "us-east-1"
}

resource "aws_vpc" "pulse_vpc" {
    cidr_block  = "10.0.0.0/16"
    enable_dns_support  = true
    tags = {
        env  = "dev"
        app  = "pulse"
    }
}

resource "aws_internet_gateway" "pulse_gateway"{
    vpc_id = "${aws_vpc.pulse_vpc.id}"
    tags = {
        env   = "dev"
        app   = "pulse"
    }
}

//data "aws_availability_zones" "avalilable" {}

resource "aws_subnet" "pulse-public-net" {
    vpc_id = "${aws_vpc.pulse_vpc.id}"
    cidr_block = "10.0.1.0/26"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch  = "true"
    tags = {
        name  = "Public Subnet"
        env   = "dev"
        app  = "pulse"
    }
}

data "aws_availability_zones" "available" {
  state = "available"
}
resource "aws_subnet" "pulse-privates-net" {
    vpc_id = "${aws_vpc.pulse_vpc.id}"
    count  = "${length(data.aws_availability_zones.available.names)}"
    cidr_block = "10.0.1${length(data.aws_availability_zones.available.names) + count.index}.0/26"
    availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
    map_public_ip_on_launch  = "false"
    tags = {
        name = "Private Subnet ${element(data.aws_availability_zones.available.names, count.index)}"
        env   = "dev"
        app  = "pulse"
    }
}

resource "aws_route_table" "pulse_route_public" {
        vpc_id = "${aws_vpc.pulse_vpc.id}"
    route {
        cidr_block  = "0.0.0.0/0"
        gateway_id  = "${aws_internet_gateway.pulse_gateway.id}"

    }
     tags = {
        env   = "dev"
        app  = "pulse"
    }
}

resource "aws_route_table_association" "pulse_sbnt_pblc_ass" {
    subnet_id   = "${aws_subnet.pulse-public-net.id}"
    route_table_id  = "${aws_route_table.pulse_route_public.id}"
}

resource "aws_security_group" "pulse_sg_ec2"{
    name    = "pulse_sg_ec2"
    vpc_id = "${aws_vpc.pulse_vpc.id}"

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]   
    }   
    
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]   
    } 
    tags = {
       env   = "dev"
       app  = "pulse"
    }
}

resource "aws_security_group" "pulse_sg_rds" {
    name    = "pulse_sg_db"
    vpc_id = "${aws_vpc.pulse_vpc.id}"
    egress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]   
    } 
}

resource "aws_db_subnet_group" "pulse_db_subnet" {
    name    = "pulse_db_subnet_group"
    subnet_ids  = "${aws_subnet.pulse-privates-net.*.id}"
}

resource "aws_db_instance" "pulse-db-rds" {
    identifier  = "pulsedbid"
    allocated_storage    = 20
    max_allocated_storage = 50
    storage_type         = "gp2"
    engine               = "mysql"
    engine_version       = "5.7"
    instance_class       = "db.t2.micro"
    name                 = "pulsedbinst"
    username             = "pulsedb"
    password             = "asdf1234"
    parameter_group_name = "default.mysql5.7"
    enabled_cloudwatch_logs_exports = ["error","slowquery"]
    maintenance_window    = "Sun:00:00-Sun:03:00"
    port  = "3306"
    db_subnet_group_name = "${aws_db_subnet_group.pulse_db_subnet.id}"
    vpc_security_group_ids  = ["${aws_security_group.pulse_sg_rds.id}"]
    tags = {
        env   = "dev"
        app  = "pulse"
    }
}

resource "aws_instance" "pulse-app-ec2" {
    ami = "ami-0b898040803850657"
    instance_type   = "t2.micro"
    subnet_id   = "${aws_subnet.pulse-public-net.id}"
    vpc_security_group_ids  = ["${aws_security_group.pulse_sg_ec2.id}"]
    tags = {
        env   = "dev"
        app  = "pulse"
    }
}
