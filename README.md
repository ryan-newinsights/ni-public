# ni-public - newinsights.ai Landing Page

Static landing page for https://newinsights.ai/

## Deployment to Google VM

### Prerequisites

- Google VM running Ubuntu/Debian
- Domain `newinsights.ai` pointed to your VM's IP address
- SSH access to the VM

### Quick Deploy

1. SSH into your Google VM:
   ```bash
   gcloud compute ssh YOUR_VM_NAME --zone=YOUR_ZONE
   # or
   ssh user@YOUR_VM_IP
   ```

2. Clone this repository:
   ```bash
   git clone https://github.com/ryan-newinsights/ni-public.git
   cd ni-public
   ```

3. Run the deployment script:
   ```bash
   sudo ./deploy.sh
   ```

The script will:
- Install nginx and certbot
- Copy files to `/var/www/newinsights`
- Obtain SSL certificates from Let's Encrypt
- Configure nginx
- Set up automatic certificate renewal

### Manual Deployment

If you prefer to deploy manually:

1. Install nginx:
   ```bash
   sudo apt update
   sudo apt install nginx certbot python3-certbot-nginx
   ```

2. Copy the landing page:
   ```bash
   sudo mkdir -p /var/www/newinsights
   sudo cp index.html /var/www/newinsights/
   sudo chown -R www-data:www-data /var/www/newinsights
   ```

3. Get SSL certificate:
   ```bash
   sudo certbot certonly --standalone -d newinsights.ai -d www.newinsights.ai
   ```

4. Install nginx config:
   ```bash
   sudo cp nginx.conf /etc/nginx/sites-available/newinsights
   sudo ln -s /etc/nginx/sites-available/newinsights /etc/nginx/sites-enabled/
   sudo rm /etc/nginx/sites-enabled/default  # Remove default site
   sudo nginx -t && sudo systemctl reload nginx
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
