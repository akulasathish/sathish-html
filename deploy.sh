#!/bin/bash 

STACK_NAME="simple-html-app-stack"
AWS_REGION="ap-south-1"  # Updated region to ap-south-1

# Check if the stack exists and delete it if necessary
aws cloudformation describe-stacks --stack-name $STACK_NAME --region $AWS_REGION > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Stack $STACK_NAME exists. Deleting the stack..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $AWS_REGION
  echo "Waiting for stack deletion to complete..."
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $AWS_REGION
else
  echo "Stack $STACK_NAME does not exist. Proceeding to creation."
fi

# Create CloudFormation stack to launch EC2
echo "Creating CloudFormation stack $STACK_NAME..."
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-body file://ec2-infra.yaml \
  --capabilities CAPABILITY_IAM \
  --region $AWS_REGION

# Wait for stack creation to complete
echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $AWS_REGION

# Retrieve EC2 instance details
INSTANCE_IP=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query "Stacks[0].Outputs[?OutputKey=='EC2InstancePublicIP'].OutputValue" \
  --output text --region $AWS_REGION)
echo "EC2 instance IP: $INSTANCE_IP"

# Deploy HTML to EC2
echo "Deploying HTML to EC2 instance with IP: $INSTANCE_IP"

# SSH into EC2 and configure httpd
ssh -i MANDEEP-KEY.pem -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << EOF
  # Update system and install httpd (Apache HTTP Server)
  sudo yum update -y
  sudo yum install -y httpd

  # Start and enable httpd
  sudo systemctl start httpd
  sudo systemctl enable httpd

  # Create directory and set permissions
  sudo mkdir -p /var/www/html
  sudo chown ec2-user:ec2-user /var/www/html
  sudo chmod 755 /var/www/html

  # Download and place index.html from new repo
  sudo wget https://raw.githubusercontent.com/akulasathish/sathish-html/main/index.html -O /var/www/html/index.html
EOF

echo "Deployment complete."
