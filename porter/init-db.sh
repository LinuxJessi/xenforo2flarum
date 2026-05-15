#!/bin/bash
# Imports the XenForo dump into the source database on first container boot.
#
# This script is mounted into /docker-entrypoint-initdb.d/, so the MySQL image's
# entrypoint runs it automatically the first time the container starts with an
# empty data directory. The dump itself is mounted separately at /seed/source.sql.
set -e

echo "[init-db] Waiting for MySQL to accept connections..."
until mysqladmin ping -hlocalhost -uroot -p"${MYSQL_ROOT_PASSWORD}" --silent; do
  echo "[init-db]   ...still waiting"
  sleep 3
done

echo "[init-db] MySQL is up — importing XenForo dump from /seed/source.sql ..."
mysql -hlocalhost -uroot -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" < /seed/source.sql
echo "[init-db] XenForo data imported into database '${MYSQL_DATABASE}'."
