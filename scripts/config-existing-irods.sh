#!/bin/bash

# config-existing-irods.sh
# Author: Michael Stealey <michael.j.stealey@gmail.com>

SERVICE_ACCOUNT_CONFIG_FILE="/etc/irods/service_account.config"
IRODS_HOME_DIR="/var/lib/irods"

# Get environment variables from iRODS setup
while read line; do export $line; done < <(cat /root/.secret/secrets.sh)
while read line; do export $line; done < <(cat ${SERVICE_ACCOUNT_CONFIG_FILE})

# get service account name
MYACCTNAME=`echo "${IRODS_SERVICE_ACCOUNT_NAME}" | sed -e "s/\///g"`

# get group name
MYGROUPNAME=`echo "${IRODS_SERVICE_GROUP_NAME}" | sed -e "s/\///g"`

##################################
# Set up Service Group and Account
##################################

# Group
set +e
CHECKGROUP=`getent group $MYGROUPNAME `
set -e
if [ "$CHECKGROUP" = "" ] ; then
  # new group
  echo "Creating Service Group: $MYGROUPNAME "
  /usr/sbin/groupadd -r $MYGROUPNAME
else
  # use existing group
  echo "Existing Group Detected: $MYGROUPNAME "
fi

# Account
set +e
CHECKACCT=`getent passwd $MYACCTNAME `
set -e

if [ "$CHECKACCT" = "" ] ; then
  # new account
  echo "Creating Service Account: $MYACCTNAME at $IRODS_HOME_DIR "
  /usr/sbin/useradd -r -d $IRODS_HOME_DIR -M -s /bin/bash -g $MYGROUPNAME -c "iRODS Administrator" $MYACCTNAME
else
  # use existing account
  # leave user settings and files as is
  echo "Existing Account Detected: $MYACCTNAME "
fi

#############
# Permissions
#############
chown -R $MYACCTNAME:$MYGROUPNAME $IRODS_HOME_DIR
chown -R $MYACCTNAME:$MYGROUPNAME /etc/irods

# set permissions on iRODS authentication mechanisms
chmod 4755 $IRODS_HOME_DIR/iRODS/server/bin/PamAuthCheck
chmod 4755 /usr/bin/genOSAuth

# start iRODS server as user irods
su irods <<'EOF'
sed -i 's/"irods_host".*/"irods_host": "localhost",/g' /var/lib/irods/.irods/irods_environment.json
/var/lib/irods/iRODS/irodsctl restart
iadmin modresc `ilsresc` host `hostname`
EOF

# Keep container in a running state
/usr/bin/tail -f /dev/null