output "load_balancer_ip" {
  value       = google_compute_global_address.spot.address
  description = "The public IP address of the load balancer"
}
