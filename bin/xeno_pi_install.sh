#!/bin/bash
if [ $# -ne 2 ];
then
  echo "Syntax: $(basename $0) <ftp_username> <ftp_password>"
  exit 1
fi

ftp_username="$1"
ftp_password="$2"
xeno_dir=`pwd`
cmd_sync_snapshots="$xeno_dir/bin/sync_snapshots.sh"
cron_sync_snapshots="/etc/cron.hourly/xeno_sync_snapshots"

# Create cron job.
echo -e "#!/bin/bash\n/bin/bash $cmd_sync_snapshots $ftp_username $ftp_password" > $cron_sync_snapshots
chmod u+x $cron_sync_snapshots
