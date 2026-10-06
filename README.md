# Carpio Travel

A travel site about my solo backpacking trip through Thailand, Cambodia, Laos and Vietnam, hosted on AWS, provisioned with Terraform and deployed with GitHub Actions.

**Live site:** [carpiotravel.com](https://carpiotravel.com)

## Why I built it

I built this project to showcase my work and something I really care about. I love traveling. I backpacked Southeast Asia alone for a couple of months, starting in Thailand, then Cambodia, Laos and finally Vietnam. I came back with so many memories and stories, and I met some amazing people along the way. Carpio Travel is a small piece of the world through my eyes.

I also wanted it to show my cloud progress over the past year. Instead of just collecting certifications, I wanted to build something real with AWS and Terraform and actually understand how it all fits together. I plan to keep adding to it (more stories, more trips, more things that went wrong).

And a lot went wrong. I was sent to the hospital on my first day in Thailand. About a week later, I made a prayer at a temple and drew a fortune stick: #4. The fortune said I was now unlucky and that no one could help me. Little did I know it would be right about the rest of the trip.

Every country after that brought something new: foods I'd never tried before, food poisoning in Cambodia, getting lost, a fever, an emergency dental procedure in Vietnam on a Tuesday afternoon, getting run over by a kid on a bicycle (also Vietnam), hotels cancelled on arrival and a lot more.

But I kept cruising. I hope the site encourages people to get out there, explore and keep going when things go wrong.

Traveling really humbles you. Riding on the back of a motorbike across the Ha Giang Loop made me feel so small in the world (in a good way). The nature there could make you cry, you know? That's my favorite part of traveling: seeing how different everything can be, and how similar people really are.

## Tech stack

AWS · Terraform · GitHub Actions · S3 · CloudFront · Route 53 · ACM · IAM · OIDC

## Architecture

![Carpio Travel architecture diagram](docs/architecture.png)

Editable source: [`docs/architecture.drawio`](docs/architecture.drawio) (open in [diagrams.net](https://app.diagrams.net))

## How it works

**Visiting the site**

1. Route 53 resolves `carpiotravel.com` and `www` to CloudFront using alias records.
2. CloudFront serves the site over HTTPS from edge locations, using a certificate from AWS Certificate Manager.
3. On a cache miss, CloudFront fetches the file from a private S3 bucket. Origin Access Control signs the request, and the bucket policy only accepts requests from this distribution.

**Deploying a change**

1. A push to `main` starts the GitHub Actions workflow.
2. GitHub issues an OIDC token, which AWS exchanges for short-lived credentials on a deploy role.
3. The workflow syncs `site/` to S3 and invalidates the CloudFront cache so the change is live within a minute or two.

## Security

- **No public buckets.** S3 Block Public Access is on for both buckets, ACLs are disabled and only CloudFront can read the site files (Origin Access Control).
- **No stored AWS keys.** GitHub Actions authenticates with OIDC and receives short-lived AWS credentials.
- **Locked-down trust policy.** The role only trusts this repo on `main`, matched by GitHub's numeric owner and repo IDs, so a re-created repo with the same name can't assume it.
- **Least-privilege deploy role.** It can upload and delete site files, list the bucket and invalidate the cache. Nothing else.
- **Encryption.** HTTPS only (HTTP redirects), TLS 1.2 minimum, and S3 server-side encryption at rest.
- **Cost guardrail.** An AWS Budgets alert emails me if monthly spend passes 80% of the limit, or is forecast to pass 100%.
- **Secrets stay out of git.** Variable and plan files are gitignored, and Terraform state lives in a private S3 bucket instead of the repo.

## Terraform state

Terraform state is stored remotely in a private, encrypted S3 bucket instead of only on my laptop.

- **Versioning** keeps every previous copy of the state, so I can recover from a bad change.
- **Native S3 locking** (`use_lockfile`, Terraform 1.10+) stops two runs from changing the state at the same time, with no DynamoDB table needed.
- **`prevent_destroy`** means the bucket can't be deleted (the state file lives there).

## Cost

The site currently costs roughly $1 a month for the Route 53 hosted zone, S3 storage and CloudFront usage, plus the yearly domain registration.

## What I learned

The hardest problem was getting GitHub Actions to assume the AWS deploy role. The first workflow run failed because it couldn't authenticate to AWS.

While troubleshooting, I found that my `github_repo` variable was set to the plain `owner/repo` name, but GitHub's OIDC token identifies my repo with unique numeric IDs (`repo:owner@id/repo@id:ref:refs/heads/main`). The trust policy was waiting for a name that GitHub never sent. After updating the variable to the ID format, the deploy worked.

It taught me the difference between a role's trust policy (who can assume it) and its permissions policy (what it can do once assumed).

After the site went live, I ran into another dilemma: the Terraform state file still only lived on my laptop (if the laptop died, Terraform would forget everything it built). I created a private S3 bucket and migrated the state into it. I turned on versioning for that bucket, so if the state file ever gets deleted or broken, I can restore an older copy.

I also realized my website bucket doesn't need versioning (the site files are already in git, so every change is saved in the commit history).

## Repo layout

```
site/                       Static site files (HTML, CSS, JS, images)
docs/
  architecture.png          Architecture diagram
  architecture.drawio       Editable diagram source
.github/workflows/
  deploy.yml                Deploys site/ to S3 on every push to main
terraform/
  providers.tf              Terraform and AWS provider versions, S3 backend, default tags
  variables.tf              Inputs (region, domain, GitHub repo, alert email)
  main.tf                   S3 bucket, CloudFront distribution, OAC, bucket policy
  dns.tf                    Route 53 zone and records, ACM certificate and validation
  github-oidc.tf            OIDC provider, deploy role and its permissions
  budgets.tf                Monthly cost budget with email alerts
  state.tf                  S3 bucket for remote Terraform state
  outputs.tf                Bucket name, distribution ID, site URL
  terraform.tfvars.example  Template for terraform.tfvars
```

## Deploy it yourself

Requirements: Terraform 1.10+, the AWS CLI, an AWS account and a domain with a Route 53 hosted zone.

1. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and set your domain, GitHub repo, branch and alert email.
2. Import your existing hosted zone into `aws_route53_zone.main` (otherwise Terraform creates a second zone your domain doesn't point to).
3. In `providers.tf`, comment out the `backend "s3"` block for the first run (the state bucket doesn't exist yet). From `terraform/`, run:
   ```
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
4. Put your state bucket name in the `backend "s3"` block, uncomment it and run `terraform init -migrate-state` to move the state into S3.
5. Update the `env` values in `.github/workflows/deploy.yml` with your bucket name and distribution ID (from `terraform output`) and your deploy role ARN, then push to `main`.

## What's next

- More travel stories
