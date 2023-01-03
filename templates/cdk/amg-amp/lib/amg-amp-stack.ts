import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as iam from 'aws-cdk-lib/aws-iam';
import { CfnJson, CfnParameter, Stack } from 'aws-cdk-lib';
import * as aps from 'aws-cdk-lib/aws-aps';
import * as grafana from 'aws-cdk-lib/aws-grafana';

export class AmgAmpStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // parameters

    const accountId = Stack.of(this).account;
    const region = Stack.of(this).region;

    new cdk.CfnOutput(this, 'oAwsRegion', {
      value: region,
      description: 'AWS region',
      exportName: 'oAwsRegion',
    });

    const rosaOidcEndpoint = new CfnParameter(this, "rosaOidcEndpoint", {
      type: "String",
      description: "ROSA cluster OIDC endpoint"
    });

    const rosaServiceAccount = new CfnParameter(this, "rosaServiceAccount", {
      type: "String",
      description: "ROSA service account used to proxy Prometheus metrics",
      default: "prometheus-k8s"
    });

    const rosaNamespace = new CfnParameter(this, "rosaNamespace", {
      type: "String",
      description: "ROSA namespace where prometheus server is installed",
      default: "prometheus"
    });

    // Amazon Managed Service for Prometheus

    const ampPolicyStringEquals = new CfnJson(this, 'ConditionJson', {
      value: {
        [`${rosaOidcEndpoint.value}:sub`]: `system:serviceaccount:${rosaNamespace.value}:${rosaServiceAccount.value}`,
      },
    });

    const ampRole = new iam.Role(this, 'rosa-amg-amp', {
      assumedBy: new iam.FederatedPrincipal(
        `arn:aws:iam::${accountId}:oidc-provider/${rosaOidcEndpoint.value}`,
        {
          StringEquals: ampPolicyStringEquals
        },
        'sts:AssumeRoleWithWebIdentity',
      ),
    });

    const ampWorkspace = new aps.CfnWorkspace(this, 'ampWorkspace');


    new cdk.CfnOutput(this, 'oAmpRwUrl', {
      value: `${ampWorkspace.attrPrometheusEndpoint}api/v1/remote_write`,
      description: 'remote write URL of the Amazon Managed Service for Prometheus workspace',
      exportName: 'ampWorkspace',
    });

    const ampPolicy = new iam.Policy(this, 'ampPolicy', {
      statements: [
        new iam.PolicyStatement({
          resources: [
            ampWorkspace.attrArn
          ],
          actions: [
            "aps:RemoteWrite",
            "aps:GetSeries",
            "aps:GetLabels",
            "aps:GetMetricMetadata"
          ],
          effect: iam.Effect.ALLOW,
        }),
      ],
    });

    ampRole.attachInlinePolicy(ampPolicy);

    new cdk.CfnOutput(this, 'oAmpRoleArn', {
      value: ampRole.roleArn,
      description: 'ARN of the IAM Role used by ROSA and Amazon Managed Service for Prometheus',
      exportName: 'ampRole',
    });

    // Amazon Managed Service for Grafana
    const amgRole = new iam.Role(this, 'amgRole', {
      assumedBy: new iam.ServicePrincipal('grafana.amazonaws.com'),
    });

    amgRole.assumeRolePolicy?.addStatements(
      new iam.PolicyStatement({
        principals: [new iam.ServicePrincipal('grafana.amazonaws.com')],
        actions: ['sts:AssumeRole'],
        effect: iam.Effect.ALLOW,
        conditions: {
          "StringEquals": {
            "aws:SourceAccount": accountId
          },
          "StringLike": {
            "aws:SourceArn": `arn:aws:grafana:${region}:${accountId}:/workspaces/*`
          }
        }
      }),
    );

    const amgPolicy = new iam.Policy(this, 'amgPolicy', {
      statements: [
        new iam.PolicyStatement({
          resources: [
            ampWorkspace.attrArn
          ],
          actions: [
            "aps:QueryMetrics",
            "aps:GetSeries",
            "aps:GetLabels",
            "aps:GetMetricMetadata"
          ],
          effect: iam.Effect.ALLOW,
        }),
        new iam.PolicyStatement({
          resources: [
            `*`
          ],
          actions: [
            "aps:DescribeWorkspace",
            "aps:ListWorkspaces",
          ],
          effect: iam.Effect.ALLOW,
        }),
      ],
    });

    amgRole.attachInlinePolicy(amgPolicy);

    const amgWorkspace = new grafana.CfnWorkspace(this, 'amgWorkspace', {
      accountAccessType: "CURRENT_ACCOUNT",
      roleArn: amgRole.roleArn,
      authenticationProviders: ["AWS_SSO"],
      permissionType: "SERVICE_MANAGED",
      dataSources: ["PROMETHEUS"]
    });

    new cdk.CfnOutput(this, 'oAmgUrl', {
      value: `https://${amgWorkspace.attrEndpoint}`,
      description: 'URL of the Amazon Managed Service for Grafana workspace',
      exportName: 'amgWorkspace',
    });
  }
}
