
# Provisionning a ROSA cluster

## ROSA cluster using PrivateLink

### Step 1: Configure the remaining ROSA cluster options and create the ROSA account roles

```bash
# Name of the cluster
export ROSA_CLUSTER_NAME=rosa-cluster

# Create account roles
rosa create account-roles --mode auto --yes
```

### Step 2: ROSA - cluster installation

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
    --subnet-ids "<ROSA_VPC_PRIVATE_SUBNET_A>,<...>,<...>" \
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

### Step 3: Cluster first access

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
