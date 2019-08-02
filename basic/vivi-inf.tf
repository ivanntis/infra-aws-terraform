provider "aws" {
    profile = "vivi_admin"
    region  = "us-east-1"
}

resource "aws_vpc" "vivi_vpc" {
    cidr_block  = "10.0.0.0/16"
    enable_dns_support  = true
    tags = {
        env  = "dev"
        app  = "vivi"
    }
}

resource "aws_internet_gateway" "vivi_gateway"{
    vpc_id = "${aws_vpc.vivi_vpc.id}"
    tags = {
        env   = "dev"
        app   = "vivi"
    }
}

//data "aws_availability_zones" "avalilable" {}

resource "aws_subnet" "vivi-public-net" {
    vpc_id = "${aws_vpc.vivi_vpc.id}"
    cidr_block = "10.0.1.0/26"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch  = "true"
    tags = {
        name  = "Public Subnet"
        env   = "dev"
        app  = "vivi"
    }
}

data "aws_availability_zones" "available" {
  state = "available"
}
resource "aws_subnet" "vivi-privates-net" {
    vpc_id = "${aws_vpc.vivi_vpc.id}"
    count  = "${length(data.aws_availability_zones.available.names)}"
    cidr_block = "10.0.1${length(data.aws_availability_zones.available.names) + count.index}.0/26"
    availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
    map_public_ip_on_launch  = "false"
    tags = {
        name = "Private Subnet ${element(data.aws_availability_zones.available.names, count.index)}"
        env   = "dev"
        app  = "vivi"
    }
}

resource "aws_route_table" "vivi_route_public" {
        vpc_id = "${aws_vpc.vivi_vpc.id}"
    route {
        cidr_block  = "0.0.0.0/0"
        gateway_id  = "${aws_internet_gateway.vivi_gateway.id}"

    }
     tags = {
        env   = "dev"
        app  = "vivi"
    }
}

resource "aws_route_table_association" "vivi_sbnt_pblc_ass" {
    subnet_id   = "${aws_subnet.vivi-public-net.id}"
    route_table_id  = "${aws_route_table.vivi_route_public.id}"
}

resource "aws_security_group" "vivi_sg_ec2"{
    name    = "vivi_sg_ec2"
    vpc_id = "${aws_vpc.vivi_vpc.id}"

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
       app  = "vivi"
    }
}

resource "aws_security_group" "vivi_sg_rds" {
    name    = "vivi_sg_db"
    vpc_id = "${aws_vpc.vivi_vpc.id}"
    ingress {
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

resource "aws_db_subnet_group" "vivi_db_subnet" {
    name    = "vivi_db_subnet_group"
    subnet_ids  = "${aws_subnet.vivi-privates-net.*.id}"
}

resource "aws_db_instance" "vivi-db-rds" {
    identifier  = "vividbid"
    allocated_storage    = 20
    max_allocated_storage = 50
    storage_type         = "gp2"
    engine               = "mysql"
    engine_version       = "5.7"
    instance_class       = "db.t2.micro"
    name                 = "vividbinst"
    username             = "vividb"
    password             = "asdf1234"
    parameter_group_name = "default.mysql5.7"
    enabled_cloudwatch_logs_exports = ["error","slowquery"]
    maintenance_window    = "Sun:00:00-Sun:03:00"
    port  = "3306"
    db_subnet_group_name = "${aws_db_subnet_group.vivi_db_subnet.id}"
    vpc_security_group_ids  = ["${aws_security_group.vivi_sg_rds.id}"]
    tags = {
        env   = "dev"
        app  = "vivi"
    }
}

resource "tls_private_key" "vivi_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "vivi_generated_key" {
  key_name   = "vivi_key_test"
  public_key = "${tls_private_key.vivi_key_pair.public_key_openssh}"
}

resource "aws_instance" "vivi-app-ec2" {
    ami = "ami-0b898040803850657"
    instance_type   = "t2.micro"
    subnet_id   = "${aws_subnet.vivi-public-net.id}"
    key_name    = "${aws_key_pair.vivi_generated_key.key_name}"
    vpc_security_group_ids  = ["${aws_security_group.vivi_sg_ec2.id}"]
    tags = {
        env   = "dev"
        app  = "vivi"
    }
}

resource "aws_iam_account_password_policy" "strict" {
    minimum_password_length = 8
    require_lowercase_characters = true
    require_numbers = true
    require_uppercase_characters = true
    require_symbols = false
    allow_users_to_change_password = true
    password_reuse_prevention = 3
    max_password_age = 180
 }
resource "aws_iam_user" "vivi-api-user" {
    name = "vivi-api"
}
resource "aws_iam_group" "vivi-admin-api" {
  name = "vivi-admin-api"
}
resource "aws_iam_group_policy_attachment" "engineering-attach" {
  group = "${aws_iam_group.vivi-admin-api.name}"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

}

resource "aws_iam_group_membership" "vivi-api-user-groups" {
    name    = "vivi-api-user-groups"
    users   = ["${aws_iam_user.vivi-api-user.name}"]
    group   = "${aws_iam_group.vivi-admin-api.name}"
}


resource "aws_s3_bucket" "vivi-layer-libs" {
  bucket = "vivilayerlambdabucket"
  acl    = "public-read"
  tags = {
    env   = "dev"
    app   = "vivi"
  }
}
