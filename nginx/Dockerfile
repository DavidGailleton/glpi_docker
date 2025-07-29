FROM nginx:stable-alpine

# Copy nginx configuration files
COPY conf.d/*.conf /etc/nginx/conf.d/

# Copy SSL certificates
COPY ssl /etc/nginx/ssl/

# Install required tools for extracting GLPI
RUN apk update && apk add --no-cache \
    tar \
    gzip \
    curl

# Set GLPI version
ENV GLPI_VERSION=10.0.19

# Create the web directory
RUN mkdir -p /var/www/html

# Download and extract GLPI
ADD https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz /tmp/

# Extract GLPI in separate steps for better error handling
RUN tar -zxf /tmp/glpi-${GLPI_VERSION}.tgz -C /tmp/
RUN cp -r /tmp/glpi/* /var/www/html/
RUN chown -R nginx:nginx /var/www/html
RUN chmod -R 755 /var/www/html
RUN rm -rf /tmp/glpi-${GLPI_VERSION}.tgz /tmp/glpi

# Set working directory
WORKDIR /var/www/html

EXPOSE 80 443

