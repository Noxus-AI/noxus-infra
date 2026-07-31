# Usage

## Deploy

This is a terraform project. Start by filling in a `deploy.tfvars` file with the necessary values:

```hcl
project_id      = "my-gcp-project-name"
region          = "eu-west1"
zone            = "eu-west1-b"
admin_email     = "something@example.com" # this needs to be a real email as it will be the only person who can login until you add others.
domain          = "my.domain.com" # Use a real domain that you can control the A record of.
whitelabel_logo = "https://logo.clearbit.com/noxus.ai" # A logo image for your organization
docker_hub_token = "" # get this from noxus
```

Then run:

```sh
terraform init -var-file=deploy.tfvars
terraform plan -var-file=deploy.tfvars
```

And if you're satisfied:

```sh
terraform apply -var-file=deploy.tfvars
```

Once the VM is up and running, you need to add the CNAME records for the 3 subdomains to point to the IP address of the load balancer.

```sh
terraform output
```

You can now access the VM at `https://my.domain.com`.

## Adding users

Login and add users in the organization settings on the bottom left.

## Adding API keys for integrations and LLMs

Login and add API keys in the admin panel on the bottom left, after updating this you will need to restart the vm for the changes to apply.
