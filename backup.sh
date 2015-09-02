#! /bin/bash
if [ -z "$1" ]; then
  # single
  databases=`mysql -u root -proot -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)"`
  for db in $databases; do
    echo "Removing existing backup for $db";
    rm -f /vagrant/dumps/exports/$db.sql
    echo "Dumping tables for $db";
    mysqldump -u root -proot $db > /vagrant/dumps/exports/$db.sql
  done
else
  # all
  echo "Removing existing backup for $1";
  rm -f /vagrant/dumps/exports/$1.sql
  echo "Dumping tables for $1";
  mysqldump -u root -proot $1 > /vagrant/dumps/exports/$1.sql
fi
