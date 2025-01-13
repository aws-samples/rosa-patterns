.PHONY: create-rosa-hcp-public
team-create-rosa-hcp-public:
	aws iam create-service-linked-role --aws-service-name elasticloadbalancing.amazonaws.com || true
	cd /work/src/examples/rosa-hcp-public && \
		terraform init \
			-backend-config="bucket=$(TFSTATE_BUCKET_NAME)" && \
		terraform apply -auto-approve

.PHONY: delete-rosa-hcp-public
team-delete-rosa-hcp-public:
	aws iam create-service-linked-role --aws-service-name elasticloadbalancing.amazonaws.com || true
	cd /work/src/examples/rosa-hcp-public && \
		terraform init \
			-backend-config="bucket=$(TFSTATE_BUCKET_NAME)" && \
		terraform apply -destroy -auto-approve

.PHONY: central-cluster-create-finalizer
central-cluster-create-finalizer:
	/bin/python3 /work/cluster-create-finalizer.py