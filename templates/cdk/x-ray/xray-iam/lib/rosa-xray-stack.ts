import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as iam from 'aws-cdk-lib/aws-iam';
import { CfnJson, CfnParameter, Stack } from 'aws-cdk-lib';

export class RosaXrayStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const accountId = Stack.of(this).account;
    const region = Stack.of(this).region;

    new cdk.CfnOutput(this, 'oRosaXrayAwsRegion', {
      value: region,
      description: 'AWS region',
      exportName: 'oRosaXrayAwsRegion',
    });

    const rosaOidcEndpoint = new CfnParameter(this, "rosaOidcEndpoint", {
      type: "String",
      description: "ROSA cluster OIDC endpoint"
    });

    const rosaServiceAccount = new CfnParameter(this, "rosaServiceAccount", {
      type: "String",
      description: "ROSA service account used to proxy Prometheus metrics",
      default: "aws-xray-daemon"
    });

    const rosaNamespace = new CfnParameter(this, "rosaNamespace", {
      type: "String",
      description: "ROSA namespace where the AWS X-Ray daemon is installed",
      default: "aws-xray"
    });

    const policyStringEquals = new CfnJson(this, 'ConditionJson', {
      value: {
        [`${rosaOidcEndpoint.value}:sub`]: `system:serviceaccount:${rosaNamespace.value}:${rosaServiceAccount.value}`,
      },
    });

    const iamRole = new iam.Role(this, 'rosa-rosa-xray', {
      assumedBy: new iam.FederatedPrincipal(
        `arn:aws:iam::${accountId}:oidc-provider/${rosaOidcEndpoint.value}`,
        {
          StringEquals: policyStringEquals
        },
        'sts:AssumeRoleWithWebIdentity',
      ),
    });


    const iamPolicy = new iam.Policy(this, 'iamPolicy', {
      statements: [
        new iam.PolicyStatement({
          resources: [
            "*" // To review
          ],
          actions: [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords"
          ],
          effect: iam.Effect.ALLOW,
        }),
      ],
    });

    iamRole.attachInlinePolicy(iamPolicy);

    new cdk.CfnOutput(this, 'oRosaXrayRoleArn', {
      value: iamRole.roleArn,
      description: 'ARN of the IAM Role used by ROSA and X-Ray',
      exportName: 'rosaXrayRole',
    });
  }
}
