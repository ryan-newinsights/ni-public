# ni-public - newinsights.ai Landing Page

Static landing page for https://newinsights.ai/

## Deployment to Google VM

### One-Liner Deploy

Deploy with a single command from your local machine:

```bash
gcloud compute ssh ryan@instance-20250908-075435 \
  --project=codeinsights-test-1 \
  --zone=us-central1-c \
  --command="\
sudo -i -u hi bash -c 'cd /home/hi/ni-public && git fetch --all && git checkout main && git pull --ff-only' && \
sudo cp /home/hi/ni-public/nginx.conf /etc/nginx/sites-available/newinsights && \
sudo cp /home/hi/ni-public/index.html /var/www/newinsights/index.html && \
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
sudo cp /home/hi/ni-public/index.html /var/www/newinsights/
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

- `index.html` - Landing page
- `nginx.conf` - Nginx configuration: static homepage + Cloud Run reverse proxy
- `deploy.sh` - Automated first-time deployment script

## Related Repositories

- [scribe](https://github.com/ryan-newinsights/scribe) - Main application (Cloud Run)
