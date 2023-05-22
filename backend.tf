provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "server_wordpress" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"

  tags = {
    Name = "Server Instance"
  }

  key_name = "key-05abb699be"

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd php mysql php-mysqlnd
    systemctl start httpd
    systemctl enable httpd

    # inicialização WordPress
    wget https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz -C /var/www/html/
    chown -R apache:apache /var/www/html/wordpress
    cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
    sed -i 's/database_name_here/wordpress/g' /var/www/html/wordpress/wp-config.php
    sed -i 's/username_here/your-db-username/g' /var/www/html/wordpress/wp-config.php
    sed -i 's/password_here/your-db-password/g' /var/www/html/wordpress/wp-config.php
    sed -i 's/localhost/your-db-hostname/g' /var/www/html/wordpress/wp-config.php
    systemctl restart httpd
  EOF

  # Porta 80 exposta
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Porta meu IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["127.0.0.1/32"]
  }

}

output "ip_publico" {
  value = aws_instance.server_wordpress.ip_publico
}

resource "aws_autoscaling_group" "escalonamento-server" {
  name                 = "escalonamento-server"
  min_size             = 1
  max_size             = 10
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.escalonamento-server.name

  tag {
    key                 = "Escalonamento-server-key"
    value               = "example-instance"
    propagate_at_launch = true
  }

  #Especifico para o monitoramento da CPU 90%
  metric {
    name               = "CPUUtilization"
    namespace          = "AWS/EC2"
    statistic          = "Average"
    unit               = "Percent"
    threshold          = 90
    evaluation_periods = 1
    period             = 60
    alarm_actions      = [aws_autoscaling_policy.escalonamento-server.arn]
  }
}

resource "aws_autoscaling_policy" "escalonamento-policy" {
  name                   = "escalonamento-policy"
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.escalonamento-policy.name
}

resource "aws_cloudwatch_metric_alarm" "alarme" {
  alarm_name          = "alarme-server"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 90
  period              = 60
  alarm_description   = "Alarme para monitorar CPU"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  unit                = "Percent"
  alarm_actions       = [aws_autoscaling_policy.alarme.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.alarme.name
  }
}

