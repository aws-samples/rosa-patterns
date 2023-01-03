# ROSA with AMG AMG

## Deployment

After login in into your ROSA cluster, run the following commands:

```bash
export ROSA_OIDC_PROVIDER=$(oc get authentication.config.openshift.io cluster -o json | jq -r .spec.serviceAccountIssuer| sed -e "s/^https:\\/\\///")

cdk deploy --parameters rosaOidcEndpoint=${ROSA_OIDC_PROVIDER}
```
