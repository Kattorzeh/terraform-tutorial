provider "aws" {
    profile= "terraform-up-and-running"
}

resource "aws_instance" "ec2_linux" {
  ami           = "ami-0230bd60aa48260c6"
  instance_type = "t2.micro"

  tags = {
    Name = "book-example-nv"
  }
}