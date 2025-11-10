FROM postgres:15

# copy migrations, seed and scripts into image
COPY migrations /migrations
COPY seed /seed
COPY scripts /scripts

# ensure scripts runnable
RUN chmod +x /scripts/run_migrations.sh

# default entrypoint will be the run script (docker-compose sets entrypoint too)
ENTRYPOINT [ "/scripts/run_migrations.sh" ]
