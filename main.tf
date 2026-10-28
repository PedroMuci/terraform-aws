terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# As duas regioes usam o mesmo perfil da AWS CLI.
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "oeste"
  region = "us-west-2"
}

# Apenas consulta as VPCs existentes: nao cria novas redes.
data "aws_vpc" "leste" {
  default = true
}

data "aws_vpc" "oeste" {
  provider = aws.oeste
  default  = true
}

# Busca uma imagem publica Amazon Linux em cada regiao.
data "aws_ami" "leste" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_ami" "oeste" {
  provider    = aws.oeste
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Acesso publico somente a porta HTTP 80 (sem SSH).
resource "aws_security_group" "leste" {
  name        = "terraform-aula-http-leste"
  description = "HTTP para demonstracao Terraform"
  vpc_id      = data.aws_vpc.leste.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "terraform-aula-http-leste" }
}

resource "aws_security_group" "oeste" {
  provider    = aws.oeste
  name        = "terraform-aula-http-oeste"
  description = "HTTP para demonstracao Terraform"
  vpc_id      = data.aws_vpc.oeste.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "terraform-aula-http-oeste" }
}

resource "aws_instance" "leste" {
  ami                         = data.aws_ami.leste.id
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.leste.id]
  associate_public_ip_address = true
  user_data                   = templatefile("${path.module}/servidor.sh.tftpl", { regiao = "us-east-1 (principal)" })
  tags                        = { Name = "terraform-aula-servidor-leste" }
}

resource "aws_instance" "oeste" {
  provider                    = aws.oeste
  ami                         = data.aws_ami.oeste.id
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.oeste.id]
  associate_public_ip_address = true
  user_data                   = templatefile("${path.module}/servidor.sh.tftpl", { regiao = "us-west-2 (reserva)" })
  tags                        = { Name = "terraform-aula-servidor-oeste" }
}

output "url_principal" {
  value = "http://${aws_instance.leste.public_ip}"
}

output "url_reserva" {
  value = "http://${aws_instance.oeste.public_ip}"
}
