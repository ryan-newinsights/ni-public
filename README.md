# ni-public - newinsights.ai Landing Page

Static landing page for https://newinsights.ai/

## Deployment to Google VM

Pushing to `main` deploys automatically via `.github/workflows/deploy.yml` —
but only when `index.html`, `impressum.html`, `privacy.html` or `nginx.conf`
changes, so a README edit does not reload nginx.

The workflow does not just run the deploy; it then fetches the live site and
compares its sha256 against the committed `index.html`, and asserts the HTML
carries a revalidation directive. A deploy that exits 0 without the new bytes
reaching a visitor fails the job.

**Why this exists:** deployment used to be a manual one-liner with nothing
tying it to a merge. In August 2026 the VM turned out to be nine commits
behind — including a fix for the signup form silently dropping submissions,
which had been merged and dead on the live site for weeks.

### One-time setup (Workload Identity Federation)

The workflow authenticates with WIF rather than a service-account JSON key, so
there is no long-lived credential in repository secrets. Run once:

```bash
PROJECT=codeinsights-test-1
NUM=$(gcloud projects describe $PROJECT --format='value(projectNumber)')
SA=ni-public-deploy@$PROJECT.iam.gserviceaccount.com

gcloud iam service-accounts create ni-public-deploy --project=$PROJECT \
  --display-name="ni-public GitHub Actions deploy"

# osAdminLogin (not osLogin) — the deploy runs sudo on the VM.
gcloud projects add-iam-policy-binding $PROJECT \
  --member="serviceAccount:$SA" --role="roles/compute.osAdminLogin"
gcloud projects add-iam-policy-binding $PROJECT \
  --member="serviceAccount:$SA" --role="roles/iap.tunnelResourceAccessor"

gcloud iam workload-identity-pools create github \
  --project=$PROJECT --location=global --display-name="GitHub Actions"

# The attribute-condition is the security boundary: without it ANY GitHub
# repository could mint tokens for this service account.
gcloud iam workload-identity-pools providers create-oidc github \
  --project=$PROJECT --location=global --workload-identity-pool=github \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='ryan-newinsights/ni-public'"

gcloud iam service-accounts add-iam-policy-binding $SA --project=$PROJECT \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/$NUM/locations/global/workloadIdentityPools/github/attribute.repository/ryan-newinsights/ni-public"

echo "GCP_WIF_PROVIDER = projects/$NUM/locations/global/workloadIdentityPools/github/providers/github"
echo "GCP_DEPLOY_SA    = $SA"
```

Then add those two values as repository secrets under
**Settings → Secrets and variables → Actions**.

Until both secrets exist the workflow fails at the auth step; the manual
one-liner below keeps working regardless.

### Manual deploy (fallback)

Deploy with a single command from your local machine:

```bash
gcloud compute ssh ryan@instance-20250908-075435 \
  --project=codeinsights-test-1 \
  --zone=us-central1-c \
  --command="\
sudo -i -u hi bash -c 'cd /home/hi/ni-public && git fetch --all && git checkout main && git pull --ff-only' && \
sudo cp /home/hi/ni-public/nginx.conf /etc/nginx/sites-available/newinsights && \
sudo cp /home/hi/ni-public/index.html /var/www/newinsights/index.html && \
sudo cp /home/hi/ni-public/impressum.html /var/www/newinsights/impressum.html && \
sudo cp /home/hi/ni-public/privacy.html /var/www/newinsights/privacy.html && \
sudo nginx -t && \
sudo systemctl reload nginx"
```

### First-Time Setup

On your first deployment, SSH into the VM and run:

```bash
gcloud compute ssh ryan@instance-20250908-075435 \
  --project=codeinsights-test-1 \
  --zone=us-central1-c
```

Then as the `hi` user:

```bash
sudo -i -u hi
cd /home/hi
git clone https://github.com/ryan-newinsights/ni-public.git
```

Set up the web directory and nginx:

```bash
# Create web root
sudo mkdir -p /var/www/newinsights
sudo chown -R www-data:www-data /var/www/newinsights

# Copy files
sudo cp /home/hi/ni-public/*.html /var/www/newinsights/
sudo cp /home/hi/ni-public/nginx.conf /etc/nginx/sites-available/newinsights
sudo ln -s /etc/nginx/sites-available/newinsights /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t && sudo systemctl reload nginx
```

### SSL Certificates

If SSL is not yet configured, obtain certificates:

```bash
sudo certbot certonly --nginx -d newinsights.ai -d www.newinsights.ai
```

## Architecture

```
DNS: newinsights.ai -> VM (34.135.140.130)

https://newinsights.ai/
├── /   (exact)        → Static landing page (this repo, served by nginx)
└── /*  (everything)   → Proxied to Cloud Run (scribe app)

https://scribe.newinsights.ai/  → Cloud Run direct (domain mapping)
```

The marketing homepage is completely isolated from scribe deployments:
- Scribe deploys to Cloud Run with zero-downtime rolling updates
- The static homepage is served directly by nginx on the VM
- nginx proxies all app routes to Cloud Run via its `.run.app` URL

## Files

- `index.html` - Marketing landing page
- `impressum.html` - Impressum (legal notice)
- `privacy.html` - Privacy Policy (GDPR)
- `nginx.conf` - Nginx configuration: static homepage + Cloud Run reverse proxy
- `deploy.sh` - Automated first-time deployment script

## Related Repositories

- [scribe](https://github.com/ryan-newinsights/scribe) - Main application (Cloud Run)
