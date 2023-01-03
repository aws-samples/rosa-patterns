#!/bin/bash

### NOTE: THIS SCRIPT IS CREATED FOR TESTING PURPOSES. USE IT ON YOUR OWN RISK.


export ROSA_CLUSTER_NAME=plink-rosa AWS_REGION=eu-west-2


#### Create AWS Infra ####

#Create VPCs
VPC_ROSA=$(aws ec2 create-vpc --cidr-block 10.1.0.0/16 | jq -r .Vpc.VpcId)
aws ec2 create-tags --resources $VPC_ROSA --tags Key=Name,Value=rosa_vpc
VPC_EGRESS=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 | jq -r .Vpc.VpcId)
aws ec2 create-tags --resources $VPC_EGRESS --tags Key=Name,Value=egress_vpc
aws ec2 modify-vpc-attribute --vpc-id $VPC_ROSA --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_EGRESS --enable-dns-hostnames

#Create Subnets
ROSA_PRIVATE_SUBNET=$(aws ec2 create-subnet --vpc-id $VPC_ROSA --cidr-block 10.1.0.0/17 | jq -r .Subnet.SubnetId)
aws ec2 create-tags --resources $ROSA_PRIVATE_SUBNET --tags Key=Name,Value=intranet-private
EGRESS_PRIVATE_SUBNET=$(aws ec2 create-subnet --vpc-id $VPC_EGRESS --cidr-block 10.0.0.0/17 | jq -r .Subnet.SubnetId)
aws ec2 create-tags --resources $EGRESS_PRIVATE_SUBNET --tags Key=Name,Value=egress-private
EGRESS_PUBLIC_SUBNET=$(aws ec2 create-subnet --vpc-id $VPC_EGRESS --cidr-block 10.0.128.0/17 | jq -r .Subnet.SubnetId)
aws ec2 create-tags --resources $EGRESS_PUBLIC_SUBNET --tags Key=Name,Value=egress-public

#Create Internet Gateway
IGW=$(aws ec2 create-internet-gateway | jq -r .InternetGateway.InternetGatewayId)
aws ec2 create-tags --resources $IGW --tags Key=Name,Value=rosa-internet-gateway
aws ec2 attach-internet-gateway --vpc-id $VPC_EGRESS --internet-gateway-id $IGW

#Create Nat Gateway
EIP=$(aws ec2 allocate-address --domain vpc | jq -r .AllocationId)
NATGW=$(aws ec2 create-nat-gateway --subnet-id $EGRESS_PUBLIC_SUBNET --allocation-id $EIP | jq -r .NatGateway.NatGatewayId)
aws ec2 create-tags --resources $EIP --resources $NATGW --tags Key=Name,Value=egress_nat_public

#Create Transit Gateway
TGW=$(aws ec2 create-transit-gateway | jq -r .TransitGateway.TransitGatewayId)
aws ec2 create-tags --resources $TGW --tags Key=Name,Value=rosa-transit-gateway
sleep 120
TGWA_VPC_ROSA=$(aws ec2 create-transit-gateway-vpc-attachment --transit-gateway-id $TGW --vpc-id $VPC_ROSA --subnet-ids $ROSA_PRIVATE_SUBNET | jq -r .TransitGatewayVpcAttachment.TransitGatewayAttachmentId)
aws ec2 create-tags --resources $TGWA_VPC_ROSA --tags Key=Name,Value=transit-gw-intranet-attachment
TGWA_VPC_EGRESS=$(aws ec2 create-transit-gateway-vpc-attachment --transit-gateway-id $TGW --vpc-id $VPC_EGRESS --subnet-ids $EGRESS_PRIVATE_SUBNET | jq -r .TransitGatewayVpcAttachment.TransitGatewayAttachmentId)
aws ec2 create-tags --resources $TGWA_VPC_EGRESS --tags Key=Name,Value=transit-gw-egress-attachment

#Create routes
TGW_RT=$(aws ec2 describe-transit-gateways --transit-gateway-id $TGW | jq -r '.TransitGateways | .[] | .Options.AssociationDefaultRouteTableId')
aws ec2 create-tags --resources $TGW_RT --tags Key=Name,Value=transit-gw-rt
aws ec2 create-transit-gateway-route --destination-cidr-block 0.0.0.0/0 --transit-gateway-route-table-id $TGW_RT --transit-gateway-attachment-id $TGWA_VPC_EGRESS > /dev/null
ROSA_VPC_RT=$(aws ec2 describe-route-tables --filters 'Name=vpc-id,Values='$VPC_ROSA'' --query 'RouteTables[].Associations[].RouteTableId' | jq '.[]' | tr -d '"')
aws ec2 create-tags --resources $ROSA_VPC_RT --tags Key=Name,Value=rosa_rt 
EGRESS_VPC_RT=$(aws ec2 describe-route-tables --filters 'Name=vpc-id,Values='$VPC_EGRESS'' --query 'RouteTables[].Associations[].RouteTableId' | jq '.[]' | tr -d '"')
EGRESS_PRIVATE_RT=$(aws ec2 create-route-table --vpc-id $VPC_EGRESS | jq -r .RouteTable.RouteTableId)
aws ec2 associate-route-table --route-table-id $EGRESS_PRIVATE_RT --subnet-id $EGRESS_PRIVATE_SUBNET > /dev/null

aws ec2 create-route --route-table-id $EGRESS_PRIVATE_RT --destination-cidr-block 0.0.0.0/0 --gateway-id $NATGW > /dev/null
aws ec2 create-route --route-table-id $EGRESS_VPC_RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW > /dev/null
aws ec2 create-route --route-table-id $EGRESS_VPC_RT --destination-cidr-block 10.1.0.0/16 --gateway-id $TGW > /dev/null
aws ec2 create-route --route-table-id $ROSA_VPC_RT --destination-cidr-block 0.0.0.0/0 --gateway-id $TGW > /dev/null



#### Create ROSA PrivateLink cluster ####

rosa create account-roles --mode auto --yes
rosa create cluster --cluster-name $ROSA_CLUSTER_NAME --region $AWS_REGION --private-link --machine-cidr=10.1.0.0/16 --sts --subnet-ids=$ROSA_PRIVATE_SUBNET --mode auto --yes



#### Associate Egress VPC immediate the ROSA domain is created ####

DNS_DOMAIN=$(rosa describe cluster --cluster $ROSA_CLUSTER_NAME -ojson | jq -r .dns.base_domain)
R53HZ_ID=$(aws route53 list-hosted-zones-by-name | jq --arg name "$ROSA_CLUSTER_NAME.$DNS_DOMAIN." -r '.HostedZones | .[] | select(.Name=="\($name)") | .Id')
aws route53 associate-vpc-with-hosted-zone --hosted-zone-id $R53HZ_ID --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_EGRESS



#### Connect to the cluster from your local machine ####

# Create an instace in EGRESS_PUBLIC_SUBNET with inbound SSH traffic
aws ec2 create-key-pair --key-name <key> --key-type rsa --key-format pem --query "KeyMaterial" --output text >  <key>.pem
chmod 400 <key>.pem
aws ec2 run-instances --image-id <ami-id> --count 1 --instance-type t2.micro --key-name <key> --subnet-id $EGRESS_PUBLIC_SUBNET --associate-public-ip-address

# Update your /etc/hosts to point openshift domains
127.0.0.1 api.$ROSA_CLUSTER_NAME.$DNS_DOMAIN
127.0.0.1 console-openshift-console.apps.$ROSA_CLUSTER_NAME.$DNS_DOMAIN
127.0.0.1 oauth-openshift.apps.$ROSA_CLUSTER_NAME.$DNS_DOMAIN

# ssh to the instance, tunnelling the traffic for your browser

 sudo ssh -i <key>.pem \
   -L 6443:api.$ROSA_CLUSTER_NAME.$DNS_DOMAIN:6443 \
   -L 443:console-openshift-console.apps.$ROSA_CLUSTER_NAME.$DNS_DOMAIN:443 \
   -L 80:console-openshift-console.apps.$ROSA_CLUSTER_NAME.$DNS_DOMAIN:80 \
    ec2-user@$<public-ip-jumphost>