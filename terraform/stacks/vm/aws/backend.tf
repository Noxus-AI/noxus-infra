terraform {
  backend "s3" {
    bucket = "noxus-images"
    region = "eu-west-1"
  }
}
