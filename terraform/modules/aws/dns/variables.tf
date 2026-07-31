variable "domain" {
  description = "Apex domain the platform is served from, e.g. \"noxus.example.com\". Must match the chart's ingress.domain."
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone ID. Empty looks the zone up by zone_name."
  type        = string
  default     = ""
}

variable "zone_name" {
  description = "Hosted zone name to look up when zone_id is empty, e.g. \"example.com.\"."
  type        = string
  default     = ""
}

variable "extra_sans" {
  description = "Additional subject alternative names. The apex and *.<domain> are always included."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the certificate."
  type        = map(string)
  default     = {}
}
