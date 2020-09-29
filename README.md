# demo-tf-wordpress-site
Example configuration for deploying WordPress on AWS

# Dependencies deployed

httpd24, php72, mysql57-server, php72-mysqlnd, wordpress, certbot, vsftpd

## Providers
AWS

## Variables

Key                  | Value
---------------------|----------------------
region | "AWS region to use when provisioning"
key_name | "ec2 instance keypair to use when provisioning"
env_prefix | "prefix used for tags and the like"
instance_size | "instance type mapping based on role"
dns_zone_id | "zone id for route 53"
wordpress_count | "number of wordpress servers to deploy"

## Process Flow

1. Deploy EC2 instance
2. Process user_Data
   * Update instance and deploy dependencies
   * Configure user
   * Start services
   * Configure apache
   * Obtain and configure certs
   * Deploy WordPress
   * Configure MySQL
   * Configure WordPress
   * Configure ftp
3. Update DNS Apex record

### Known issues
None

### Planned enhancements
Define a certificate refresh cron


## Author
**Dave Hart**
[blog](http://davehart.co.uk)