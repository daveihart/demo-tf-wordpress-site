##################################################################################
# LOCALS
##################################################################################

locals {
  common_tags = {
    env = var.env_prefix
  }
}

# BACKEND

terraform {
  backend "remote" {
    organization = "org" # org name from step 2.
    workspaces {
      name = "name-of-workspace-in-terraform-cloud" # name for your app's state.
    }
  }
}

# DATA Sources

data "aws_vpc" "vpc" {
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}
output "vpc" {
  value = data.aws_vpc.vpc.id
}

data "aws_subnet" "public" {
  tags = {
    Name = "${var.env_prefix}-public"
  }
}

data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# RESOURCES

# SECURITY GROUPS #

# WordPress security group 
resource "aws_security_group" "wordpress-sg" {
  name   = "${var.env_prefix}_wordpress_sg"
  vpc_id = data.aws_vpc.vpc.id
  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FTP access
  ingress {
    from_port   = 20
    to_port     = 21
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FTP access
  ingress {
    from_port   = 1024
    to_port     = 1048
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

# HTTP access - needed for Certbot
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# INSTANCES #

resource "aws_instance" "wordpress" {
  count                  = var.wordpress_count
  ami                    = data.aws_ami.aws-linux.id
  instance_type          = var.instance_size["wordpress"]
  subnet_id              = data.aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.wordpress-sg.id]
  key_name               = var.key_name
  tags      = merge(local.common_tags, { Name = "${var.env_prefix}-wordpress" })
  user_data = <<EOF
          #!/bin/bash
          sudo yum update -y
          sudo yum install -y httpd24 php72 mysql57-server php72-mysqlnd
          sudo service mysqld start
          sudo service httpd start
          sudo chkconfig httpd on
          sudo chkconfig mysqld on
          sudo usermod -a -G apache ec2-user
          sudo chown -R ec2-user:apache /var/www
          sudo yum install -y mod24_ssl
          sudo yum-config-manager --enable epel
          sudo wget https://dl.eff.org/certbot-auto
          sudo chmod a+x certbot-auto
          sudo echo "<VirtualHost *:80>" >> /etc/httpd/conf/httpd.conf
          sudo echo "ServerName yourdomain.co.uk" >> /etc/httpd/conf/httpd.conf
          sudo echo "DocumentRoot /var/www/html" >> /etc/httpd/conf/httpd.conf
          sudo echo "</VirtualHost>" >> /etc/httpd/conf/httpd.conf
          sudo ./certbot-auto --authenticator apache --debug --agree-tos -m "your email" --installer apache -d "yourdomain.co.uk" --pre-hook "httpd -k stop" --post-hook "httpd -k start" -n
          sudo wget https://wordpress.org/latest.tar.gz
          sudo tar -xzf latest.tar.gz
          mysql -u root -e "delete from mysql.user where user='';drop database if exists test;delete from mysql.db where db='test' or db='test\\_%';flush privileges;"
          mysql -u root -e "create user 'wordpress-user'@'localhost' identified by 'supersecretpassword';create database wordpressdb;grant all privileges on wordpressdb.* to 'wordpress-user'@'localhost';FLUSH PRIVILEGES;"
          cp /wordpress/wp-config-sample.php /wordpress/wp-config.php
          sed -i "s/define( 'DB_NAME', 'database_name_here' );/define( 'DB_NAME', 'wordpressdb' );/g" /wordpress/wp-config.php
          sed -i "s/define( 'DB_USER', 'username_here' );/define( 'DB_USER', 'wordpress-user' );/g" /wordpress/wp-config.php
          sed -i "s/define( 'DB_PASSWORD', 'password_here' );/define( 'DB_PASSWORD', 'supersecretpassword' );/g" /wordpress/wp-config.php
          sed -i "s/define( 'AUTH_KEY',         'put your unique phrase here' );/define( 'AUTH_KEY',         'unique-salt,' );/g" /wordpress/wp-config.php
          sed -i "s/define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );/define( 'SECURE_AUTH_KEY',  'unique-salt' );/g" /wordpress/wp-config.php
          sed -i "s/define( 'LOGGED_IN_KEY',    'put your unique phrase here' );/define( 'LOGGED_IN_KEY',    'unique-salt' );/g" /wordpress/wp-config.php
          sed -i "s/define( 'NONCE_KEY',        'put your unique phrase here' );/define( 'NONCE_KEY',        'unique-salt' );/g" /wordpress/wp-config.php
          sed -i "s/define( 'AUTH_SALT',        'put your unique phrase here' );/define( 'AUTH_SALT',        'unique-salt' );/g" /wordpress/wp-config.php
          sed -i "s/define( 'SECURE_AUTH_SALT', 'put your unique phrase here' );/define( 'SECURE_AUTH_SALT', 'unique-salt' );/g" /wordpress/wp-config.php
          sed -i "s/define( 'LOGGED_IN_SALT',   'put your unique phrase here' );/define( 'LOGGED_IN_SALT',   'unique-salt' );/g" /wordpress/wp-config.php
          sed -i "s/define( 'NONCE_SALT',       'put your unique phrase here' );/define( 'NONCE_SALT',       'unique-salt' );/g" /wordpress/wp-config.php 
          cp -r wordpress/* /var/www/html/
          sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' httpd.conf
          sudo yum install php72-gd -y
          sudo service httpd restart
          sudo yum install vsftpd -y
          sed -i "s/anonymous_enable=Yes;/anonymous_enable=No;/g" /etc/vsftpd/vsftpd.conf
          sudo echo "pasv_enable=YES" >> /etc/vsftpd/vsftpd.conf
          sudo echo "pasv_min_port=1024" >> /etc/vsftpd/vsftpd.conf
          sudo echo "pasv_max_port=1048" >> /etc/vsftpd/vsftpd.conf
          sudo echo "pasv_addr_resolve=YES" >> /etc/vsftpd/vsftpd.conf
          sudo echo "pasv_address=yourdomain.co.uk" >> /etc/vsftpd/vsftpd.conf
          sudo useradd -a -G wordpress-user
          sudo echo -e "supersecretpassword" | passwd wordpress 
          sudo chmod 2775 /var/www
          sudo find /var/www -type d -exec sudo chmod 2775 {} \;
          sudo find /var/www -type f -exec sudo chmod 0664 {} \;
    EOF
}

# Route53 #
resource "aws_route53_record" "wordpress" {
  zone_id         = var.dns_zone_id
  name            = "."
  type            = "A"
  ttl             = "5"
  records         = [aws_instance.wordpress[0].public_ip]
  allow_overwrite = true
}
