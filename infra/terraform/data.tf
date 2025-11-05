data "aws_availability_zones" "available" {}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}