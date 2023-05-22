provider "aws" {
  region = "us-east-1" 
}

resource "aws_instance" "server_wordpress" {
  ami           = "ami-0c94855ba95c71c99" # substitua pela AMI desejada
  instance_type = "t2.micro"             

  tags = {
    Name = "Server Instance"
  }

  key_name = "your-key-pair" # substitua pelo nome do par de chaves existente na sua conta AWS

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd php mysql php-mysqlnd
    systemctl start httpd
    systemctl enable httpd

    # Instalação do WordPress
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

  # Regras de segurança
  vpc_security_group_ids = ["your-security-group"]

  # Definição de regras de ingresso
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["127.0.0.1"] 
  }

  # Definição de regras de egresso (saída)
  #egress {
    #from_port   = 0
    #to_port     = 0
    #protocol    = "-1"
    #cidr_blocks = ["0.0.0.0/0"]
  #}
}

output "public_ip" {
  value = aws_instance.example.public_ip
}

resource "aws_autoscaling_group" "example" {
  name                 = "example-asg"
  min_size             = 1
  max_size             = 10
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.example.name

  tag {
    key                 = "Name"
    value               = "example-instance"
    propagate_at_launch = true
  }

  #Especifico para o monitoramento da CPU
  metric {
    name               = "CPUUtilization"
    namespace          = "AWS/EC2"
    statistic          = "Average"
    unit               = "Percent"
    threshold          = 90
    evaluation_periods = 1
    period             = 60
    alarm_actions      = [aws_autoscaling_policy.example.arn]
  }
}

resource "aws_autoscaling_policy" "example" {
  name                   = "example-asg-policy"
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.example.name
}

resource "aws_cloudwatch_metric_alarm" "example" {
  alarm_name          = "example-asg-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 90
  period              = 60
  alarm_description   = "This metric monitors CPU utilization"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  unit                = "Percent"
  alarm_actions       = [aws_autoscaling_policy.example.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }
}

