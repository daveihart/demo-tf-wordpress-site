# VARIABLES

variable "region" {
  description = "AWS region to use when provisioning"
  type        = string
  default     = "eu-west-2"
}
variable "key_name" {
  description = "ec2 instance keypair to use when provisioning"
  type        = string
  default     = "keypair"
}
variable "env_prefix" {
  description = "prefix used for tags and the like"
  type        = string
  default     = "dev"
}
variable "instance_size" {
  description = "instance type mapping based on role"
  type        = map(string)
  default     = { wordpress = "t2.micro" }

}
variable "dns_zone_id" {
  description = "zone id for route 53"
  type        = string
  default     = "secret_aws_route_53_zone"
}
variable "wordpress_count" {
  description = "number of wordpress servers to deploy"
  type        = number
  default     = 1
}
