# ROSA CloudFormation

This repository provides AWS CloudFormation templates that help create example VPC architectures suitable for deploying [private Red Hat OpenShift on AWS (ROSA) clusters with AWS PrivateLink](https://aws.amazon.com/blogs/containers/red-hat-openshift-service-on-aws-private-clusters-with-aws-privatelink/).

## Deployment

### Pre-requisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [ROSA CLI](https://github.com/openshift/rosa/releases)
- [jq](https://stedolan.github.io/jq/download/0)

### Step 1: AWS CloudFormation

Available AWS CloudFormation templates:

| #   | Setup                                               | Description                                                                               | Architecture                                                          | AZ support             | CloudFormation template                                            |
| --- | --------------------------------------------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------- | ---------------------- | ------------------------------------------------------------------ |
| 1   | PrivateLink cluster for Centralized Internet Egress | Uses a TransitGateay attached to a ROSA Private VPC and an Egress VPC, single NAT Gateway | [rosa-privatelink-egress-vpc](assets/rosa-privatelink-egress-vpc.png) | Single AZ and Multi AZ | [rosa-privatelink-egress-vpc.yml](rosa-privatelink-egress-vpc.yml) |

Update the following command to launch one of the CloudFormation template above, using the AWS CLI:

```bash
# AWS region to install OpenShift
export AWS_DEFAULT_REGION=us-west-2
# AWS CloudFormation Stack name
export AWS_STACK_NAME=rosa-networking

aws cloudformation create-stack --stack-name $AWS_STACK_NAME --template-body file://rosa-privatelink-egress-vpc.yml
```

### Step 2: ROSA - initialisation

Once step 1 is completed, the ROSA configuration and account roles can be created as per the following steps.

1. Extract the VPC CIDR ranges where OpenShift will be deployed:

```bash
# An existing VPC CIDR that OpenShift will be using
export ROSA_VPC_CIDR=`aws cloudformation describe-stacks --stack-name $AWS_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='oRosaVpcCIDR'].OutputValue" --output text`
echo $ROSA_VPC_CIDR 

# The subnets for OpenShift
# /!\ Depending on how many Availibility Zones the CloudFormation stack uses, run all or some of the following commands to retrieve the subnets in each Availibility Zone
export ROSA_VPC_PRIVATE_SUBNET_A=`aws cloudformation describe-stacks --stack-name $AWS_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='oRosaVpcSubnetA'].OutputValue" --output text`
echo $ROSA_VPC_PRIVATE_SUBNET_A

# Optional steps if single AZ cluster
export ROSA_VPC_PRIVATE_SUBNET_B=`aws cloudformation describe-stacks --stack-name $AWS_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='oRosaVpcSubnetB'].OutputValue" --output text`
echo $ROSA_VPC_PRIVATE_SUBNET_B

export ROSA_VPC_PRIVATE_SUBNET_C=`aws cloudformation describe-stacks --stack-name $AWS_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='oRosaVpcSubnetC'].OutputValue" --output text`
echo $ROSA_VPC_PRIVATE_SUBNET_C
```

2. Configure the remaining ROSA cluster options and create the ROSA account roles:

```bash
# Name of the cluster
export ROSA_CLUSTER_NAME=rosa-cluster

# Create account roles
rosa create account-roles --mode auto --yes
```

### Step 3: ROSA - cluster installation

Create the ROSA private cluster using the following commands:

```bash
# Create ROSA cluster
rosa create cluster \
    --cluster-name $ROSA_CLUSTER_NAME \
    --region $AWS_DEFAULT_REGION \
    --private-link \
    --sts \
    --machine-cidr ${ROSA_VPC_CIDR} \
    --multi-az \
    --subnet-ids "${ROSA_VPC_PRIVATE_SUBNET_A},${ROSA_VPC_PRIVATE_SUBNET_B},${ROSA_VPC_PRIVATE_SUBNET_C}" \
    --mode auto \
    --yes
```

You must then proceed with the following steps **during** cluster installation.

---

IMPORTANT: If DNS resolution is not configured as per the following steps, the ROSA cluster will fail to be created. This is because the boostrap and provisioned nodes must be able to use internal DNS name resolution in order to resolve OpenShift API endpoints **during** cluster installation.

---

1. Find the current status of the cluster with the `rosa list cluster` or `watch "rosa list cluster"` commands. At creation time, the cluster status will be `pending`. After 1 to 5m, the installation will start automatically.

2. When the cluster status is *installing*, run the following commands:

```bash
VPC_EGRESS=`aws cloudformation describe-stacks --stack-name $AWS_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='oEgressVpc'].OutputValue" --output text`
echo "Egress VPC Id: $VPC_EGRESS"
DNS_DOMAIN=$(rosa describe cluster --cluster $ROSA_CLUSTER_NAME -ojson | jq -r .dns.base_domain)
echo "ROSA Cluster Domain Name: $DNS_DOMAIN"

# The following step may fail if the cluster installation has not reached the DNS configuration stage. 
# Please repeat the command until the Route 53 Hosted Zone is found
R53HZ_ID=$(aws route53 list-hosted-zones-by-name | jq --arg name "$ROSA_CLUSTER_NAME.$DNS_DOMAIN." -r '.HostedZones | .[] | select(.Name=="\($name)") | .Id')
echo "ROSA Cluster Route 53 Hosted Zone Id: $R53HZ_ID"
aws route53 associate-vpc-with-hosted-zone --hosted-zone-id $R53HZ_ID --vpc VPCRegion=$AWS_DEFAULT_REGION,VPCId=$VPC_EGRESS
```

You can see the cluster installation logs during the process by running: `rosa logs install -c $ROSA_CLUSTER_NAME --watch`.

### Step 4 - Cluster access

You can access the PrivateLink cluster from a local machine (via an EC2 instance) using the following commands:

```bash
# Create EC2 key pair for SSH access
aws ec2 create-key-pair --key-name $ROSA_CLUSTER_NAME --key-type rsa --key-format pem --query "KeyMaterial" --output text > $ROSA_CLUSTER_NAME.pem
chmod 400 $ROSA_CLUSTER_NAME.pem

# Create EC2 instance in EGRESS_PUBLIC_SUBNET with inbound SSH traffic
VPC_EGRESS_PUBLIC_SUBNET=`aws cloudformation describe-stacks --stack-name $AWS_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='oEgressVpcPublicSubnet'].OutputValue" --output text`
echo "Egress Public Subnet: $VPC_EGRESS_PUBLIC_SUBNET"
aws ec2 run-instances --image-id <ami-id> --count 1 --instance-type t2.micro --key-name $ROSA_CLUSTER_NAME --subnet-id $VPC_EGRESS_PUBLIC_SUBNET --associate-public-ip-address

# Run the following command and add the output to your /etc/hosts
echo 127.0.0.1 api.$ROSA_CLUSTER_NAME.$DNS_DOMAIN
echo 127.0.0.1 console-openshift-console.apps.$ROSA_CLUSTER_NAME.$DNS_DOMAIN
echo 127.0.0.1 oauth-openshift.apps.$ROSA_CLUSTER_NAME.$DNS_DOMAIN

# ssh to the instance, tunnelling the traffic for your browser
export EC2_PUBLIC_IP=`aws ec2 describe-addresses | jq -r '.Addresses[0].PublicIp'`
echo $EC2_PUBLIC_IP
ssh -i $ROSA_CLUSTER_NAME.pem \
   -L 6443:api.$ROSA_CLUSTER_NAME.$DNS_DOMAIN:6443 \
   -L 443:console-openshift-console.apps.$ROSA_CLUSTER_NAME.$DNS_DOMAIN:443 \
   -L 80:console-openshift-console.apps.$ROSA_CLUSTER_NAME.$DNS_DOMAIN:80 \
    ec2-user@$EC2_PUBLIC_IP
```

### Decommissioning

Delete the ROSA cluster and CloudFormation stack by running the following commands:

```bash
rosa delete cluster -c $ROSA_CLUSTER_NAME
aws cloudformation delete-stack --stack-name $AWS_STACK_NAME
```

## Tests

To run the test, you will need to install [Docker](https://docs.docker.com/get-docker/) and [cfn-lint](https://github.com/aws-cloudformation/cfn-lint) and verify that the linting and security scanning tests are successful by using the following command: `bash test/run.sh`.

---

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
