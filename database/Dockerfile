# Use the official PostGIS image as the base
FROM postgis/postgis:13-3.1

# Install the pg_cron extension
RUN apt-get update \
    && apt-get install -y postgresql-13-cron \
    && rm -rf /var/lib/apt/lists/*

# Copy the custom postgresql.conf file
COPY postgresql.conf /etc/postgresql/custom-postgresql.conf

# Set the custom configuration file as the default
CMD ["postgres", "-c", "config_file=/etc/postgresql/custom-postgresql.conf"]
