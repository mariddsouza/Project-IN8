#Create Server
provider "aws" {
  region = "us-east-1" 
}

resource "aws_instance" "server" {
  ami           = "ami-053b0d53c279acc90" # AMI Ubuntu
  instance_type = "t2.micro" 

  tags = {
    Name = "Server"
  }
}