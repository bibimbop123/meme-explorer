# Security Policy

## Supported Versions

We take security seriously and provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We appreciate the security research community's efforts to help keep Meme Explorer secure.

### How to Report

**Please DO NOT file a public GitHub issue for security vulnerabilities.**

Instead, please report security vulnerabilities via one of the following methods:

1. **Email:** Send details to `security@your-domain.com`
2. **Private Advisory:** Use [GitHub Security Advisories](https://github.com/your-username/meme-explorer/security/advisories/new)

### What to Include

When reporting a vulnerability, please include:

- **Description:** Clear description of the vulnerability
- **Impact:** Potential impact and attack scenario
- **Steps to Reproduce:** Detailed steps to reproduce the issue
- **Proof of Concept:** Code, screenshots, or video demonstration
- **Suggested Fix:** If you have recommendations (optional)
- **Your Contact Info:** How we can reach you for follow-up

###Response Timeline

We commit to the following response times:

- **Initial Response:** Within 48 hours of report
- **Status Update:** Within 7 days with assessment
- **Resolution Timeline:** Depends on severity
  - **Critical:** 7 days
  - **High:** 14 days
  - **Medium:** 30 days
  - **Low:** 90 days

## Security Measures

Meme Explorer implements the following security practices:

### Application Security

- **Authentication:** Secure OAuth 2.0 flow with Reddit
- **Authorization:** Role-based access control (RBAC)
- **Session Management:** Secure session tokens with HttpOnly cookies
- **CSRF Protection:** CSRF tokens on all state-changing operations
- **Input Validation:** Comprehensive input sanitization
- **Output Encoding:** Protection against XSS attacks
- **SQL Injection Prevention:** Parameterized queries throughout

### Infrastructure Security

- **HTTPS Only:** TLS 1.2+ for all connections
- **Security Headers:** CSP, HSTS, X-Frame-Options, etc.
- **Rate Limiting:** Rack::Attack prevents brute force and DDoS
- **Dependency Scanning:** Regular Bundler audit checks
- **Environment Isolation:** Separate dev/staging/production environments

### Data Protection

- **Password Hashing:** BCrypt with appropriate work factor
- **Sensitive Data:** OAuth tokens encrypted at rest
- **PII Handling:** Minimal collection, secure storage
- **Data Retention:** Automatic cleanup of old sessions/logs

## Known Security Considerations

### Third-Party Services

- **Reddit API:** OAuth tokens stored securely, refreshed automatically
- **Google AdSense:** Policies followed for data collection
- **Redis:** Connection authentication required, not exposed publicly
- **PostgreSQL:** Strong passwords, connection pooling with SSL

### Recommended Practices

For users deploying Meme Explorer:

1. **Use Environment Variables:** Never commit secrets to git
2. **Enable 2FA:** On all admin accounts
3. **Regular Updates:** Keep dependencies up to date
4. **Monitor Logs:** Review security logs regularly
5. **Backup Data:** Regular encrypted backups
6. **Limit Admin Access:** Principle of least privilege

## Security Checklist for Deployment

- [ ] All environment variables properly configured
- [ ] HTTPS enabled with valid SSL certificate
- [ ] Database credentials strong and rotated regularly
- [ ] Redis password set and connections encrypted
- [ ] Session secrets are random and secure
- [ ] Admin accounts use strong passwords + 2FA
- [ ] Rate limiting configured appropriately
- [ ] Security headers verified (securityheaders.com)
- [ ] Dependency vulnerabilities checked (`bundle audit`)
- [ ] Logs configured and monitored
- [ ] Backups automated and tested
- [ ] Incident response plan documented

## Past Security Issues

No security vulnerabilities have been publicly disclosed for version 1.x.

## Security Credits

We appreciate responsible disclosure and will credit security researchers in our release notes (with permission).

Thank you for helping keep Meme Explorer secure!

---

**Last Updated:** July 20, 2026  
**Next Review:** October 20, 2026
