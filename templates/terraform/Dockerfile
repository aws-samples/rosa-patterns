FROM amazonlinux

ENV TEAM_NUMBER=

RUN dnf update -y && dnf install -y python39 make git unzip jq wget yum-utils gcc tar
RUN yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo && dnf install -y terraform
RUN wget https://github.com/openshift/rosa/releases/download/v1.2.41/rosa_Linux_x86_64.tar.gz && tar -xvf rosa_Linux_x86_64.tar.gz && mv rosa /usr/local/bin/rosa && chmod +x /usr/local/bin/rosa && rm -f rosa_Linux_x86_64.tar.gz
RUN wget -qO- https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz | tar -xvz -C /usr/local/bin/
RUN wget -qO- https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash && mv ./kustomize /usr/local/bin/
RUN curl -O https://bootstrap.pypa.io/get-pip.py && python3 get-pip.py && rm get-pip.py
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update

WORKDIR /work
COPY . /work

RUN pip3 install -r requirements.txt

CMD ['/usr/bin/make', 'create-rosa-hcp-public']