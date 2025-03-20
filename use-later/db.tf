locals {
  postgres_user     = base64decode(data.kubernetes_secret.zodh_video_secrets.data["POSTGRES_USER"])
  postgres_password = base64decode(data.kubernetes_secret.zodh_video_secrets.data["POSTGRES_PASSWORD"])
}

### Database Configuration ###
variable "db_password" {
  description = "Senha do banco de dados"
  type        = string
  sensitive   = true
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "rds-security-group"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier           = "videousersdatabase"
  engine              = "postgres"
  engine_version      = "15"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username           = "video_db_user"
  password           = var.db_password
  db_name            = "videousersdatabase"
  publicly_accessible = true
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}