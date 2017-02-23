# Consul + Vault + Nomad (via Terraform)
...and a tiny bit of Packer...

This is a sample / demo / instructional project with the goal of demonstrating how to piece together an infrastructure based on HashiCorp build and runtime tools.

Additionally, the project contains examples (_still a work in progress_) that serve to illustrate the following 3 use cases for Vault:

- Secrets Management (secrets for machines)
    - Generic & Dynamic secret backends (e.g. MySQL secret backend)
    - Secure introduction (e.g. using aws-ec2 auth)
    - Vault secrets lifecycle (e.g. using Consul Template and/or envconsul)

- Encryption-as-a-Service (encrypt data, messages, and communication in-transit and at-rest)
    - Encrypt all sensitive data at-rest using the Transit secret backend
    - Use the PKI secret backend to secure communication with certificates
    - HMAC all messages in-transit

- Privileged Access Management (secrets for humans)
    - Create policies for Vault to authorize an authenticate user
    - Use the Generic secret backend to store user credentials used by humans
    - Use the  AWS secret backend to dynamically generate IAM credentials used to talk to AWS
    - Use the SSH secret backend to dynamically generate SSH credentials for remote hosts
    - Authenticate using one of the human auth backends (e.g. GitHub, Username & Password, LDAP, Tokens)
    - Explain or show how to revoke and rotate these credentials early and initiate break glass procedures

## Approach
Firstly, this project was heavily influenced by a number of examples provided by HashiCorp, especially:
- https://github.com/hashicorp/best-practices/
- https://github.com/hashicorp/atlas-examples/
  
This project is organized into three phases:

1. Using Terraform, we deploy a simple ::**_not_** best-practices:: infrastructure (public subnets, instance profiles, security groups, etc.) on AWS, consisting of the following:
  
    - A Consul cluster
     
        - This cluster utilizes the [`retry_join_ec2` configuration object][retry_join_ec2] in order to join with other Consul servers by querying for appropriate EC2 instance tags.
        - DNS resolver provided by [dnsmasq] (e.g. to be able to perform DNS queries such as `dig wordpress.service.consul`).

    - Vault server(s)
     
        - Configured to use Consul as its backend, which automatically enables [Vault HA mode][vault_ha].
        - Uses the Consul client to provide service discovery for Vault

2. Initialize and unseal the Vault server(s). Additionally, set up some basic policies, roles, and the following:

    - [AWS-EC2 auth backend][aws_ec2_auth]: for allowing instances to obtain Vault tokens based on their AMI ID or instance profile. We are using this to provide secure introduction of Nomad servers in order to [integrate with Vault][nomad_vault_integration].
    - [MySQL dynamic secret backend][mysql_backend] in order to provide dynamic, lease-based credentials for accessing a MySQL database.
    - Any [additional secret backends][secret_backends] in order to illustrate usage.

3. Once the base infrastructure is complete, and Vault is setup, we again use Terraform to deploy the Nomad cluster consisting of the following:

    - Nomad server(s)
        - Uses the Consul client to provide [service discovery][nomad_service_discovery] for Nomad jobs.
        - Integrated with Vault to allow [creating and distributing Vault tokens to Nomad jobs][nomad_vault_task].
    - Nomad client(s)
        - X number of worker instances on which the Nomad server(s) schedule jobs.
        - The Nomad clients use a pre-baked AMI created using Packer, since the Docker installation adds a significant amount of time to instance startup.
        - The Terraform files for this phase point to the state produced from the phase 1 deployment (`base-infrastructure`) using the [remote state backend for local filesystem][remote_state_local].

## Requirements

### AWS Credentials

A deliberate decision was made to not utilize any [Atlas] functionality in this project. Instead, we are building all artifacts locally. As such, only the following environment variables are required:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_DEFAULT_REGION
```
Additionally, Terraform can obtain your AWS credentials [using these methods][terraform_aws_creds].

### Build Packer AMIs

This project uses [Packer] to generate an AMI for the Nomad cluster, with Docker pre-installed in order to speed up the deployment process a bit.

Ideally, you should pre-bake as much as possible into AMIs for each component of the system and only send over bootstrap configuration via Terraform (or other provisioners). Packer allows you to easily build various machine images as part of your CI / CD pipeline.

Building our Nomad client AMI is very straightforward. The `hashi-demo/packer/nomad-client directory` contains a JSON file with the image and build definition. Navigate to this directory and perform the following:

1. Validate the template:
```
$ packer validate nomad-client.json
Template validated successfully.
```

2. Build the image:
```
$ packer build nomad-client.json
...
==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs: AMIs were created:

us-east-1: ami-5a885f4c
```
### Generate SSH Keys

Finally, be sure to generate the SSH keys that will be used to access your instances by running the the following command from the top-level directory (`hashi-demo`):
```
$ shared/ssh_keys/generate_key_pair.sh demo
```
A key name is required and this project assumes that the name "`demo`" will be used (e.g. _demo.pem_ & _demo.pub_).

**_TODO:_** _refactor to allow setting of the key name via variable_.

## Provision the Base Infrastructure

The Terraform file `terraform/base-infrastructure/main.tf` contains all variable definitions. Adjust values accordingly. For example, if multiple subnets are required, adjust the `vpc_cidrs` variable as needed. The Terraform AWS resource definitions have been implemented with `count` iterators where appropriate to allow us to scale up as needed.

Once all variables have been set, from the `base-infrastructure` directory, run the following:
- `terraform get`
- `terraform plan`
- And if all looks good, `terraform apply` to provision

**_IMPORTANT:_** Make sure to run Terraform from the this directory first. The resources in the `nomad-cluster` directory depend on the state produced from this step.

## Perform Vault Setup

Once the base infrastructure has been provisioned, public IP addresses for the servers created will be output to the console.

Change to the top-level directory (`hashi-demo`) and use SSH to connect to the Vault server:
```
...
servers_consul = [
    52.90.98.47
]
servers_vault = [
    184.72.67.30
]
...

$ chmod 0400 shared/ssh_keys/demo.pem

$ ssh -i shared/ssh_keys/demo.pem ubuntu@184.72.67.30
```
Once logged into the Vault server, initialize Vault:
```
$ vault init

Unseal Key 1: 9uqBraMl5OofD2ZSzKbCOCP9tOSy2p+xVJgZ7Fbn8+MB
Unseal Key 2: 24LCAkhYjxFzYFaC17cDjOxcj4NIc6Iku1XaCjhQxLYC
Unseal Key 3: Ql9zGrFj3UbbfMu6Q0HVE6woWnrVONznJjBZEhg42CkD
Unseal Key 4: XhbV6r9ShvYuwrz3m8WMyVrMwf3iha3feiV1BtIW9WIE
Unseal Key 5: x8tk8kZp1KGG3iHPDzNaVhq4FAR/ztMc50D2HvJ+6f0F
Initial Root Token: f79dbbec-f41d-9f92-221a-18401daff77a

Vault initialized with 5 keys and a key threshold of 3. Please
securely distribute the above keys. When the Vault is re-sealed,
restarted, or stopped, you must provide at least 3 of these keys
to unseal it again.

Vault does not store the master key. Without at least 3 keys,
your Vault will remain permanently sealed.
...
```
Next, unseal using the above keys (you will repeat this 3 times, with 3 different keys):
```
$ vault unseal 9uqBraMl5OofD2ZSzKbCOCP9tOSy2p+xVJgZ7Fbn8+MB

Sealed: true
Key Shares: 5
Key Threshold: 3
Unseal Progress: 1
...
```
Finally, authenticate using the _Initial Root Token_:
```
$ vault auth f79dbbec-f41d-9f92-221a-18401daff77a

uccessfully authenticated! You are now logged in.
token: f79dbbec-f41d-9f92-221a-18401daff77a
token_duration: 0
token_policies: [root]
...
```
Once authenticated with Vault, create run the initial authentication setup script, provided for you in the `.demo/` directory:
```
$ cd demo

$ initial-auth-setup.sh
```
This will create the initial policies, roles, and enable AWS-EC2 auth, that our Nomad cluster will use.

## Provision the Nomad Cluster

Similar to the above, the `nomad-cluster` project uses the file "`main.tf`" to set variables for the environment. However, this project depends mostly on the remote state (stored on the local filesystem) of the `base-infrastructure` for properly deploying into the same AWS infrastructure:
```
data "terraform_remote_state" "base-infrastructure" {
  backend = "local"
  config {
    path = "${path.module}/../base-infrastructure/terraform.tfstate"
  }
}
```
The only other variables that need to be set are specific to the Nomad cluster size that is desired. Additionally, this is where you'd enter the AMI ID of the Nomad client image created by Packer:
```
# Pre-baked AMI using Packer (see [PROJECT_ROOT]/packer/nomad-client)
variable "client_ami" {
  default = "ami-5a885f4c"
}
```
Once all variables have been set, from the `nomad-cluster` directory, run the following:
- `terraform get`
- `terraform plan`
- And if all looks good, `terraform apply` to provision

Once the Nomad cluster has been provisioned, public IP addresses for the servers created will be output to the console. You can use these, as above, to SSH into a Nomad server so that we can start submitting some jobs.

#### Submitting Jobs

Job examples are available in [shared/jobs/](shared/nomad/jobs). See the
[Getting Started guide](https://www.nomadproject.io/intro/getting-started/jobs.html)
for how to submit and monitor jobs.

## Environment Teardown

In order to teardown the entire environment, we need to work in the reverse from above.

Run `terraform destroy` from the `nomad-cluster` directory first, and then from the `base-infrastructure` directory.


[retry_join_ec2]: https://www.consul.io/docs/agent/options.html#retry_join_ec2
[dnsmasq]: http://www.thekelleys.org.uk/dnsmasq/doc.html
[vault_ha]: https://www.vaultproject.io/docs/concepts/ha.html
[aws_ec2_auth]: https://www.vaultproject.io/docs/auth/aws-ec2.html
[nomad_vault_integration]: https://www.nomadproject.io/docs/vault-integration/
[mysql_backend]: https://www.vaultproject.io/docs/secrets/mysql/index.html
[secret_backends]: https://www.vaultproject.io/docs/secrets/index.html
[nomad_service_discovery]: https://www.nomadproject.io/docs/agent/configuration/consul.html
[nomad_vault_task]: https://www.nomadproject.io/docs/agent/configuration/vault.html
[terraform_aws_creds]: https://www.terraform.io/docs/providers/aws/
[packer]: https://www.packer.io/intro/
[remote_state_local]: https://www.terraform.io/docs/state/remote/local.html
[atlas]: (https://atlas.hashicorp.com/)