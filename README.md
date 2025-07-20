# CiviCRM Buildkit Docker Environment

This repository contains a Docker-based development environment for CiviCRM Buildkit. It uses Docker Compose to run a multi-container application.

## Architecture

The environment has been configured to use a modern Nginx and PHP-FPM stack, which is a common setup for high-performance PHP applications.

The following services are defined in `docker-compose.yml`:

- **`nginx`**: The web server. It listens on port `7890` and reverse-proxies PHP requests to the `civicrm` service.
- **`civicrm`**: A PHP-FPM container that runs the CiviCRM Buildkit application. This container holds the CiviCRM codebase and build tools.
- **`mysql`**: A MySQL 8.0 database server for CiviCRM data storage.
- **`phpmyadmin`**: A web interface for managing the MySQL database, accessible on port `7891`.
- **`maildev`**: A development SMTP server that catches all outgoing emails for inspection, accessible on port `7892`.

## How to Use

1.  **Build and Start:**
    Build the images and start all services in detached mode.

    ```bash
    docker compose down && docker compose up -d --build && docker compose logs -f
    ```

2.  **Create a CiviCRM Site:**
    Use `civibuild` inside the `civicrm` container to create a new site. For example, to create a Drupal 9 site named `d9`:

    ```bash
    docker compose exec civicrm chown -R buildkit:buildkit /buildkit
    docker compose exec -u buildkit civicrm civibuild create standalone-composer stable
    ```

    The site's files will be located in the `./build/standalone-composer` directory on the host.

3.  **Access Services:**
    - **CiviCRM Site:** `http://<sitename>.localhost:7890` (e.g., `http://d9.localhost:7890`)
    - **phpMyAdmin:** `http://localhost:7891`
    - **MailDev:** `http://localhost:7892`

## Next Steps for Production Readiness

This environment is configured for **development**. Do not use it in production without making the following changes.

### 1. Externalize Secrets and Configuration

Hardcoded credentials are a security risk. Use environment variables for all secrets.

**Example:**

Create a `.env` file in the project root (and add it to `.gitignore`):

```env
# .env
MYSQL_ROOT_PASSWORD=a_very_strong_password
MYSQL_USER=civicrm
MYSQL_PASSWORD=another_strong_password
MYSQL_DATABASE=civicrm
```

Update `docker-compose.yml` to use these variables:

```yaml
# docker-compose.yml
services:
  mysql:
    build: .
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
    volumes:
      - mysql:/var/lib/mysql
    restart: unless-stopped
  # ... other services
```

You would also need to update `amp.services.yml` to use these environment variables for the DSN, which can be passed into the `civicrm` container. This may require a custom entrypoint script to substitute the variables.

### 2. Create a Production Dockerfile

Use a multi-stage `Dockerfile` to create a lean, secure production image. The build stage would contain all build tools (`git`, `nodejs`, `sudo`, etc.), while the final stage would only contain the minimal dependencies needed to run the application.

- Remove development tools like `vim`, `nano`, `sudo`, and `git`.
- Disable Xdebug, as it has a performance overhead.

### 3. Use a Production Docker Compose File

Create a separate `docker-compose.prod.yml` or use `docker-compose.override.yml` for production.

- Remove development services like `phpmyadmin` and `maildev`.
- Map ports `80` and `443` instead of `7890`.
- Configure restart policies (e.g., `unless-stopped` is already set, which is good).

### 4. Configure Production Services

- **Nginx**:
  - Configure it to use a real domain name instead of `*.localhost`.
  - Add SSL/TLS configuration (e.g., using Let's Encrypt certificates) to enable HTTPS.
- **Mail**:
  - Update `msmtprc` or configure CiviCRM's mail settings to use a real production SMTP service (e.g., SendGrid, Amazon SES). Do not use MailDev in production.
- **civibuild.conf**:
  - Update `URL_TEMPLATE` to use your production domain and HTTPS.

### 5. Logging and Monitoring

For production, you may want to ship logs from Nginx and PHP-FPM to a centralized logging service (like an ELK stack, Graylog, or a cloud provider's service) for better monitoring and alerting.
