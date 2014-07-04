USER=${USER:-super}
PASS=${PASS:-super}

pre_start_action() {
  # Echo out info to later obtain by running `docker logs container_name`
  echo "POSTGRES_USER=$USER"
  echo "POSTGRES_PASS=$PASS"
  echo "POSTGRES_DATA_DIR=$DATA_DIR"
  if [ ! -z $DB ];then echo "POSTGRES_DB=$DB";fi

  # test if DATA_DIR has content
  if [[ ! "$(ls -A $DATA_DIR)" ]]; then
      echo "Initializing PostgreSQL at $DATA_DIR"

      # Copy the data that we generated within the container to the empty DATA_DIR.
      cp -R /var/lib/pgsql/9.3/data/* $DATA_DIR
      #mv /var/lib/pgsql/9.3/data /var/lib/pgsql/9.3/data.old
      #ln -s $DATA_DIR /var/lib/pgsql/9.3
  fi

  # Ensure postgres owns the DATA_DIR
  chown -R postgres $DATA_DIR
  # Ensure we have the right permissions set on the DATA_DIR
  chmod -R 700 $DATA_DIR
  touch $DATA_DIR/db_is_initialzed

}

post_start_action() {
  echo "Creating the superuser: $USER"
  setuser postgres psql -q <<-EOF
    DROP ROLE IF EXISTS $USER;
    CREATE ROLE $USER WITH ENCRYPTED PASSWORD '$PASS';
    ALTER USER $USER WITH ENCRYPTED PASSWORD '$PASS';
    ALTER ROLE $USER WITH SUPERUSER;
    ALTER ROLE $USER WITH LOGIN;
EOF

  # create database if requested
  if [ ! -z "$DB" ]; then
    for db in $DB; do
      echo "Creating database: $db"
      setuser postgres psql -q <<-EOF
      CREATE DATABASE $db WITH OWNER=$USER ENCODING='UTF8';
      GRANT ALL ON DATABASE $db TO $USER
EOF
    done
  fi

  if [[ ! -z "$EXTENSIONS" && ! -z "$DB" ]]; then
    for extension in $EXTENSIONS; do
      for db in $DB; do
        echo "Installing extension for $db: $extension"
        # enable the extension for the user's database
        setuser postgres psql $db <<-EOF
        CREATE EXTENSION "$extension";
EOF
      done
    done
  fi

}
