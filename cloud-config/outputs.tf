output "load_balancer_hostname" {
  value = aws_lb.python_app.dns_name
}