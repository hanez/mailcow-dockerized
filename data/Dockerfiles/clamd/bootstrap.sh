#!/bin/bash

if [[ "${SKIP_CLAMD}" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
  echo "SKIP_CLAMD=y, skipping ClamAV..."
  sleep 365d
  exit 0
fi

# Prepare log pipes
mkdir -p /var/log/clamav
touch /var/log/clamav/clamd.log /var/log/clamav/freshclam.log
chown -R clamav:clamav /var/log/clamav/
chown root:tty /dev/console
chmod g+rw /dev/console

# Prepare whitelist
if [[ -s /etc/clamav/whitelist.ign2 ]]; then
  cp /etc/clamav/whitelist.ign2 /var/lib/clamav/whitelist.ign2
  chown clamav:clamav /var/lib/clamav/whitelist.ign2
fi
if [[ ! -f /var/lib/clamav/whitelist.ign2 ]]; then
  echo "Example-Signature.Ignore-1" > /var/lib/clamav/whitelist.ign2
fi
chown clamav:clamav /var/lib/clamav/whitelist.ign2

dos2unix /var/lib/clamav/whitelist.ign2
sed -i '/^\s*$/d' /var/lib/clamav/whitelist.ign2

BACKGROUND_TASKS=()

(
while true; do
  sleep 1m
  freshclam
  sleep 1h
done
) &
BACKGROUND_TASKS+=($!)

clamd &
BACKGROUND_TASKS+=($!)

while true; do
  for bg_task in ${BACKGROUND_TASKS[*]}; do
    if ! kill -0 ${bg_task} 1>&2; then
      echo "Worker ${bg_task} died, stopping container waiting for respawn..."
      kill -TERM 1
    fi
    sleep 10
  done
done
