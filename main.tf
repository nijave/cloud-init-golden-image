terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# resource "aws_acmpca_certificate_authority" "elasticsearch" {
#   certificate_authority_configuration {
#     key_algorithm     = "RSA_4096"
#     signing_algorithm = "SHA512WITHRSA"

#     subject {
#       common_name = "elasticsearch"
#     }
#   }

#   permanent_deletion_time_in_days = 7
# }

# resource "aws_acmpca_certificate" "elasticsearch-ca" {
#   certificate_authority_arn   = aws_acmpca_certificate_authority.elasticsearch.arn
#   certificate_signing_request = aws_acmpca_certificate_authority.elasticsearch.certificate_signing_request
#   signing_algorithm           = "SHA512WITHRSA"

#   template_arn = "arn:aws:acm-pca:::template/RootCACertificate/V1"

#   validity {
#     type  = "YEARS"
#     value = 1
#   }
# }

# resource "aws_acmpca_certificate_authority_certificate" "elasticsearch-ca" {
#   certificate_authority_arn = aws_acmpca_certificate_authority.elasticsearch.arn

#   certificate       = aws_acmpca_certificate.elasticsearch-ca.certificate
#   certificate_chain = aws_acmpca_certificate.elasticsearch-ca.certificate_chain
# }

data "aws_vpc" "default" {
    default = true
}

resource "aws_route53_zone" "internal-zone" {
    name = "dev.us-east-2.corp."

    vpc {
        vpc_id = data.aws_vpc.default.id
    }
}

resource "aws_iam_role" "elasticsearch" {
    name = "elasticsearch-node"
}