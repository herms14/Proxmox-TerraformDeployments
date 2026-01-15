# Service Name

Brief description of what this service does.

## Quick Start

1. Clone this repository
2. Modify `service.yml` with your service configuration
3. Update `config/docker-compose.yml` with your container definition
4. Push to `main` branch - deployment happens automatically

## Configuration

### service.yml

The `service.yml` file defines:
- **Service metadata**: name, description, category
- **Deployment target**: which Docker host to deploy to
- **Networking**: ports, Traefik routing, DNS
- **Secrets**: which GitLab CI/CD variables to inject

### GitLab CI/CD Variables

Add service-specific secrets as CI/CD variables at the project or group level:
- Go to Settings → CI/CD → Variables
- Add variables referenced in `service.yml` secrets section

### Required Group Variables

These should be set at the GitLab group level:
- `SSH_PRIVATE_KEY` (File type) - SSH key for deployment
- `DISCORD_WEBHOOK_URL` - Discord notifications
- `OPNSENSE_API_KEY` - DNS automation
- `OPNSENSE_API_SECRET` - DNS automation

## Deployment

Deployments are triggered automatically when:
- Changes are pushed to `main` branch
- Changes affect `service.yml` or `config/**`

Manual deployment: Pipeline → Run Pipeline

## Rollback

To rollback to previous version:
1. Go to CI/CD → Pipelines
2. Find the pipeline you want
3. Click "rollback" job → Run

## URLs

- **Service**: https://SERVICE_SUBDOMAIN.hrmsmrflrii.xyz
- **GitLab**: https://gitlab.hrmsmrflrii.xyz/GROUP/PROJECT
