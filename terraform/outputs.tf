output "instance_public_ips" {
  description = "Les adresses IP publiques des instances EC2"
  value       = [aws_instance.web_1.public_ip, aws_instance.web_2.public_ip]
}

output "alb_dns_name" {
  description = "L'adresse DNS du Load Balancer pour tester l'application"
  value       = aws_lb.web_alb.dns_name
}