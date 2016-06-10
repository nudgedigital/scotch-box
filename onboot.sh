#! /bin/bash

# Create symbolic links to all sites
cd /var/www/
for d in /var/www/* ; do
  BASE=$(basename $d);
  if [ $BASE == 'aliases' ]; then
    continue;
  fi
  DIR=$(dirname $d);
  ALIAS=$BASE;
  if [ ! -e $DIR/aliases/$BASE.local ]; then
    echo "Creating HTTP webroot for $ALIAS"
    if [ -d $d/public_html ]; then
      sudo ln -s $d/public_html aliases/$BASE.local
    else
      sudo ln -s $d aliases/$BASE.local
    fi
  fi
  if [ ! -e $DIR/aliases/www.$BASE.local ]; then
    echo "Creating HTTPS webroot for $ALIAS"
    if [ -d $d/public_html ]; then
      sudo ln -s $d/public_html  aliases/www.$BASE.local
    else
      sudo ln -s $d  aliases/www.$BASE.local
    fi
  fi
done