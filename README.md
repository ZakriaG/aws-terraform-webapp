# Terraform Infrastructure for Django Web Application

This repository contains Terraform code to set up infrastructure on AWS 
for running a Django web application. 
To show how to integrate a Django web-app within Terraform, I've incorporated my Django web-app [FitnessLog](https://github.com/ZakriaG/FitnessLog.git).
The Terraform infrastructure code setup includes two EC2 web servers and a Load Balancer.
Before proceeding, ensure you have the required AWS credentials and Terraform installed.

## Prerequisites
1. [Terraform](https://www.terraform.io/downloads.html)
2. AWS CLI configured with appropriate credentials (`aws configure`)

## Usage

### 1. Clone the Repository
```bash
git clone <repository-url>
cd <repository-directory>
```

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Configure Variables
Edit the `variables.tf` file to set the required variables such as AWS region and instance type.

### 4. Plan the Infrastructure
```bash
terraform plan
```

### 5. Apply the Infrastructure
Once the load balancer is set up and the application is deployed, 
you can access the web-app
through the load balancer's DNS name. 
Simply open a web browser and enter the DNS name.

For example, if your load balancer DNS name 
is my-load-balancer-1234567890.us-west-2.elb.amazonaws.com,
you would enter this address in your web browser to 
access the web-app.
```bash
terraform apply
```

### 6. Destroy the Infrastructure (When Needed)
```bash
terraform destroy
```

## Terraform Files

- `main.tf`: Defines the AWS resources including EC2 instances, a VPC, subnets, security groups, and load balancers.
- `variables.tf`: Contains the variables used in the main configuration.
- `terraform.tfvars`: Example variable values for the infrastructure.

## Infrastructure Details

- Two EC2 instances for running the Django web app.
- An Application Load Balancer to distribute traffic.
- Security groups and rules for network access.
- A Virtual Private Cloud (VPC) with subnets.
- AWS resources to support Django web app deployment.

## Note

Before applying this Terraform configuration, make sure you have reviewed and adjusted all the necessary variables and security settings. Additionally, ensure that you have the required permissions to create and manage AWS resources.

## After Running Terraform Apply

After running `terraform apply`, if you need to switch from a local backend to a remote AWS backend for managing Terraform state, you can uncomment the following code block in the `main.tf` file:

```hcl
backend "s3" {
  bucket         = "django-tf-state"
  key            = "/django/terraform.tfstate"
  region         = var.region
  dynamodb_table = "terraform-state-locking"
  encrypt        = true
}
```

Then, run `terraform init` again to switch to the remote backend. This is recommended for production use.
