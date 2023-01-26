# ROSA STS cluster creation

Create an STS _ROSA_ cluster using Terraform.

The default installation will create a public ROSA cluster in a single availability zone, with STS enabled.

## Get started resources

- Terraform OpenShift Cluster Manager (OCM) Provider documentation: <https://github.com/openshift-online/terraform-provider-ocm>
- Terraform on AWS: <https://developer.hashicorp.com/terraform/tutorials/aws-get-started>

## Deployment

### Cluster

**Step 1** - Install the required Terraform provider plugins

```bash
cd cluster/
terraform init
```

You should see an output similar to this:

```bash

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Reusing previous version of openshift-online/ocm from the dependency lock file
- Installing openshift-online/ocm v0.1.9...
- Installed openshift-online/ocm v0.1.9 (self-signed, key ID A911C280438A0BDD)
- Using previously-installed hashicorp/aws v4.50.0

...
```

**Step 2** - Find your ROSA authentication token - see [OpenShift Console]( https://console.redhat.com/openshift/token,)

**Step 3** - Prepare your ROSA environment

Update the following environment variables to configure your AWS region and cluster configuration:

```bash
export AWS_REGION=ap-southeast-2

export TF_VAR_rosa_token=<rosa-token>
export TF_VAR_rosa_cluster_name=
export TF_VAR_rosa_operator_role_prefix=...
export TF_VAR_aws_region=${AWS_REGION}
export TF_VAR_aws_availability_zones=["ap-southeast-2a"]
```

**Step 4** - Provision your ROSA cluster

Run this command: `terraform apply`

**EXAMPLE**

```bash
export AWS_REGION=ap-southeast-2
export TF_VAR_aws_region=ap-southeast-2
export TF_VAR_aws_availability_zones='["ap-southeast-2a"]'

export TF_VAR_rosa_token=<rosa-token>
export TF_VAR_rosa_cluster_name=my-cluster
export TF_VAR_rosa_operator_role_prefix=my-prefix
terraform init
terraform apply -auto-approve
```

Expected output:

```bash

data.aws_caller_identity.current: Reading...
data.aws_caller_identity.current: Read complete after 2s [id=<aws-account-id>]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following
symbols:
  + create

Terraform will perform the following actions:

  # ocm_cluster_rosa_classic.rosa_sts_cluster will be created
  + resource "ocm_cluster_rosa_classic" "rosa_sts_cluster" {
      + api_url              = (known after apply)
      + availability_zones   = [
          + "ap-southeast-2a",
        ]
      + aws_account_id       = "<aws-account-id>"
      + aws_private_link     = (known after apply)
      + ccs_enabled          = (known after apply)
      + cloud_region         = "ap-southeast-2"
      + compute_machine_type = (known after apply)
      + compute_nodes        = (known after apply)
      + console_url          = (known after apply)
      + etcd_encryption      = (known after apply)
      + external_id          = (known after apply)
      + host_prefix          = (known after apply)
      + id                   = (known after apply)
      + machine_cidr         = (known after apply)
      + multi_az             = (known after apply)
      + name                 = "my-cluster"
      + pod_cidr             = (known after apply)
      + properties           = {
          + "rosa_creator_arn" = "arn:aws:iam::<aws-account-id>:user/<aws-user>"
        }
      + service_cidr         = (known after apply)
      + state                = (known after apply)
      + sts                  = {
          + instance_iam_roles   = {
              + master_role_arn = "arn:aws:iam::<aws-account-id>:role/ManagedOpenShift-ControlPlane-Role"
              + worker_role_arn = "arn:aws:iam::<aws-account-id>:role/ManagedOpenShift-Worker-Role"
            }
          + oidc_endpoint_url    = (known after apply)
          + operator_role_prefix = "my-cluster"
          + role_arn             = "arn:aws:iam::<aws-account-id>:role/ManagedOpenShift-Installer-Role"
          + support_role_arn     = "arn:aws:iam::<aws-account-id>:role/ManagedOpenShift-Support-Role"
          + thumbprint           = (known after apply)
        }
      + version              = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + cluster_id = (known after apply)
ocm_cluster_rosa_classic.rosa_sts_cluster: Creating...
ocm_cluster_rosa_classic.rosa_sts_cluster: Still creating... [10s elapsed]
ocm_cluster_rosa_classic.rosa_sts_cluster: Creation complete after 15s [id=<cluster-id>]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

cluster_id = "<cluster-id>"
```

The cluster will go into "waiting" state until the necessary [ROSA Cluster Manager IAM account roles](https://docs.openshift.com/rosa/rosa_planning/rosa-sts-ocm-role.html) are created.

You can verify the cluster state with the command `rosa list cluster`.

Continue with the next steps to provision the IAM roles.

### IAM account roles deployment

**Step 1** - Find your ROSA authentication token - see [OpenShift Console]( https://console.redhat.com/openshift/token,)

**Step 2** - Export Terraform outputs

```bash
cd cluster/
export TF_VAR_rosa_token=<rosa-token>
export TF_VAR_cluster_id=$(terraform output -json cluster_data | jq -r .id)
export TF_VAR_operator_role_prefix=$(terraform output -json cluster_data | jq -r .sts.operator_role_prefix)
export TF_VAR_oidc_endpoint_url=$(terraform output -json cluster_data | jq -r .sts.oidc_endpoint_url)
export TF_VAR_oidc_thumbprint=$(terraform output -json cluster_data | jq -r .sts.thumbprint)
export TF_VAR_account_role_prefix=$(terraform output -json rosa_account_role_prefix | jq -r .)
```

**Step 3** - Install the required Terraform provider plugins

```bash
cd roles/
terraform init
```

You should see an output similar to this:

```bash

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Reusing previous version of openshift-online/ocm from the dependency lock file
- Installing openshift-online/ocm v0.1.9...
- Installed openshift-online/ocm v0.1.9 (self-signed, key ID A911C280438A0BDD)
- Using previously-installed hashicorp/aws v4.50.0

...
```

**Step 4** - Provision your ROSA IAM account roles

```bash
cd roles/
terraform init
terraform apply -auto-approve
```

The expected output should show the main IAM roles being created and the cluster state will change to _installing_.

You can verify the cluster state with the command `rosa list cluster`.
