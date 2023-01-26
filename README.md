# ROSA Patterns

This repository provides [AWS CloudFormation](https://aws.amazon.com/cloudformation/) and AWS Cloud Development Kit ([AWS CDK](https://aws.amazon.com/cdk/)) templates that can be used to create example architectures applicable to Red Hat OpenShift Service on AWS (ROSA).

## Pre-requisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) or [AWS Cloud Development Kit (AWS CDK) CLI](https://docs.aws.amazon.com/cdk/v2/guide/cli.html)
- [ROSA CLI](https://github.com/openshift/rosa/releases)
- [jq](https://stedolan.github.io/jq/download/0)

## ROSA Patterns

| #   | Setup                                               | Description                                                                               | Instructions              | When to run? |
| --- | --------------------------------------------------- | ----------------------------------------------------------------------------------------- | ------------------------- | ------------ |
| 1   | PrivateLink cluster for Centralized Internet Egress | Uses a TransitGateay attached to a ROSA Private VPC and an Egress VPC, single NAT Gateway. Supports Single AZ and Multi AZ | [rosa-privatelink-egress-vpc](templates/cloudformation/privatelink/README.md) |Before provisioning a ROSA cluster |
| 2   | Create a ROSA cluster using Terraform  | Uses Terraform to provision a public ROSA cluster in a single AZ | [rosa-tf](templates/terraform/README.md) | For provisioning a ROSA cluster |
| 3   | Setting up ROSA to use Amazon Managed Service for Prometheus and Amazon Managed Service for Grafana  | Uses AWS CDK to provision the ROSA required IAM roles and Prometheus + Grafana workspaces | [rosa-amg-amp-cdk](templates/cdk/amg-amp/README.md) | After provisioning a ROSA cluster |

## Tests

To run the repository tests, you will need to install [Docker](https://docs.docker.com/get-docker/) and [cfn-lint](https://github.com/aws-cloudformation/cfn-lint) and verify that the linting and security scanning tests are successful by using the following command: `bash test/run.sh`.

---

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
