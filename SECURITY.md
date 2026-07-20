# Security Policy

## Supported Versions

We actively support and provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 2.5.x   | :white_check_mark: |
| 2.0.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Reporting a Vulnerability

We take security seriously at Meme Explorer. If you discover a security vulnerability, please follow these steps:

### 1. **DO NOT** open a public GitHub issue

Security vulnerabilities should be reported privately to prevent exploitation.

### 2. Email Security Team

Send details to: **security@memeexplorer.com** (or create private security advisory on GitHub)

Include in your report:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

### 3. Response Timeline

- **Initial Response:** Within 48 hours
- **Status Update:** Within 7 days
- **Fix Timeline:** Critical issues within 30 days

### 4. Disclosure Policy

- We will acknowledge your report within 48 hours
- We will provide regular updates on fix progress
- We will credit you in the security advisory (unless you prefer to remain anonymous)
- We request 90 days before public disclosure

## Security Best Practices

### For Users

1. **Keep Dependencies Updated**
   ```bash
   bundle update
   ```

2. **Use Environment Variables**
   - Never commit `.env` files
   - Rotate secrets regularly
   - Use strong passwords

3. **Enable Security Headers**
   - CSP (Content Security Policy)
   - HSTS (HTTP Strict Transport Security)
   - X-Frame-Options

### For Developers

1. **Code Review Requirements**
   - All PRs require review
   - Security-sensitive changes require 2+ reviews
   - Run `bundle audit` before merging

2. **Dependency Scanning**
   ```bash
   bundle audit check --update
   ```

3. **Static Analysis**
   ```bash
   rubocop --only Security
   brakeman --run
   ```

## Known Security Considerations

### Authentication
- Sessions expire after 24 hours of inactivity
- Passwords hashed with bcrypt (cost factor 12)
- CSRF protection enabled on all state-changing requests

### Rate Limiting
- API endpoints: 100 requests/minute per IP
- Auth endpoints: 5 attempts/minute per IP
- Configurable in `config/rack_attack.rb`

### Data Protection
- User data encrypted at rest (PostgreSQL TDE)
- Redis connections secured with AUTH
- Secrets managed via environment variables

## Security Hardening Checklist

- [ ] HTTPS enforced in production
- [ ] Security headers configured
- [ ] Input validation on all user inputs
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (escaped output)
- [ ] CSRF tokens on forms
- [ ] Rate limiting enabled
- [ ] Dependency scanning automated
- [ ] Secrets rotated quarterly
- [ ] Access logs monitored

## Third-Party Security

### Dependencies
We use automated tools to monitor dependencies:
- Dependabot for GitHub
- Bundle Audit for Ruby gems
- Snyk for container scanning

### External Services
- **Reddit API:** OAuth 2.0, scoped access
- **Redis:** AUTH enabled, network isolated
- **PostgreSQL:** SSL connections, least privilege

## Incident Response

See [INCIDENT_RESPONSE.md](./docs/INCIDENT_RESPONSE.md) for our incident response playbook.

## Contact

- Security Email: security@memeexplorer.com
- PGP Key: [Available on request]
- Bug Bounty: Not currently available

## Hall of Fame

We acknowledge security researchers who responsibly disclose vulnerabilities:

(List will be updated as reports are received and resolved)

---

**Last Updated:** July 19, 2026
