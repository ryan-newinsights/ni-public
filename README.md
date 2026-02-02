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
https://newinsights.ai/
├── /                  → Static landing page (this repo)
├── /login             → Proxied to Flask app :8000
├── /login-email       → Proxied to Flask app :8000
├── /auth/*            → Proxied to Flask app :8000
└── /static/*          → Proxied to Flask app :8000

https://scribe.newinsights.ai/  → Separate scribe app (different config)
```

## Files

- `index.html` - Landing page
- `nginx.conf` - Nginx configuration with SSL and proxy rules
- `deploy.sh` - Automated deployment script

## Related Repositories

- [scribe](https://github.com/ryan-newinsights/scribe) - Main application (runs on scribe.newinsights.ai)
