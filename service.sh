#!/system/bin/sh
# NCM Tether - Replace RNDIS with NCM for USB tethering
# Monitors configfs for rndis links and swaps to ncm

MODDIR=${0%%/*}
LOGFILE=/data/local/tmp/ncm-tether.log

GADGET=/config/usb_gadget/g1
FUNC_DIR=$GADGET/functions
CONFIG_DIR=$GADGET/configs/b.1
NCM_FUNC=$FUNC_DIR/ncm.0

echo "" > $LOGFILE

log() {
  echo "$(date '+%m-%d %H:%M:%S') $1" >> $LOGFILE
}

# Wait for boot
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 1
done
sleep 2

log "=== NCM Tether service started ==="

if [ ! -d "$NCM_FUNC" ]; then
  log "ERROR: ncm.0 not found"
  exit 1
fi

# Find symlinks pointing to a rndis function
find_rndis_links() {
  for link in $CONFIG_DIR/function* $CONFIG_DIR/f*; do
    [ -L "$link" ] || continue
    readlink "$link" | grep -q "rndis" && echo "$link"
  done
}

# Swap rndis -> ncm and rename interface
swap_to_ncm() {
  # Record which slot has the rndis link
  first_slot=""
  for link in $(find_rndis_links); do
    slot=$(basename "$link")
    [ -z "$first_slot" ] && first_slot="$slot"
    rm "$link"
    log "Removed: $slot"
  done

  [ -z "$first_slot" ] && return 1

  # Set ncm interface name BEFORE binding
  echo "rndis0" > $NCM_FUNC/ifname 2>/dev/null

  # Create ncm symlink
  ln -s "$NCM_FUNC" "$CONFIG_DIR/$first_slot"
  log "Created: $first_slot -> ncm.0"

  # Rebind UDC
  udc=$(cat $GADGET/UDC)
  echo "" > $GADGET/UDC
  sleep 0.3
  echo "$udc" > $GADGET/UDC
  log "UDC rebound: $udc"

  # Wait for interface to appear
  sleep 1

  # Rename usb0 -> rndis0 if needed
  if ip link show usb0 >/dev/null 2>&1; then
    ip link set usb0 down
    ip link set usb0 name rndis0
    ip link set rndis0 up
    log "Renamed usb0 -> rndis0"
  fi

  # Tell tethering service about the interface
  ndc tether interface add rndis0 2>/dev/null
  log "Swap complete"
}

# Write the inotifyd callback handler to a temp script
# inotifyd calls it as a child process with: $1=event $2=dir $3=filename
HANDLER=/data/local/tmp/ncm-onconfig.sh
cat > "$HANDLER" << 'SCRIPT'
#!/system/bin/sh
GADGET=/config/usb_gadget/g1
CONFIG_DIR=$GADGET/configs/b.1
NCM_FUNC=$GADGET/functions/ncm.0
LOGFILE=/data/local/tmp/ncm-tether.log

log() { echo "$(date '+%m-%d %H:%M:%S') $1" >> $LOGFILE; }

find_rndis_links() {
  for link in $CONFIG_DIR/function* $CONFIG_DIR/f*; do
    [ -L "$link" ] || continue
    readlink "$link" | grep -q "rndis" && echo "$link"
  done
}

# Only react to create/moved_to events, ignore our own ncm.0 symlinks
case "$1" in *c*|*e*) ;; *) exit 0;; esac
[ "$3" = "ncm.0" ] && exit 0

find_rndis_links | grep -q . || exit 0
log "RNDIS detected (event: $1/$3), swapping to NCM..."

first_slot=""
for link in $(find_rndis_links); do
  slot=$(basename "$link")
  [ -z "$first_slot" ] && first_slot="$slot"
  rm "$link"
  log "Removed: $slot"
done
[ -z "$first_slot" ] && exit 0

echo "rndis0" > $NCM_FUNC/ifname 2>/dev/null
ln -s "$NCM_FUNC" "$CONFIG_DIR/$first_slot"
log "Created: $first_slot -> ncm.0"

udc=$(cat $GADGET/UDC)
echo "" > $GADGET/UDC
sleep 0.3
echo "$udc" > $GADGET/UDC
log "UDC rebound: $udc"

sleep 1
if ip link show usb0 >/dev/null 2>&1; then
  ip link set usb0 down
  ip link set usb0 name rndis0
  ip link set rndis0 up
  log "Renamed usb0 -> rndis0"
fi
ndc tether interface add rndis0 2>/dev/null
log "Swap complete"
SCRIPT
chmod 755 "$HANDLER"

# Main loop
if command -v inotifyd >/dev/null 2>&1; then
  log "Using inotifyd (event-driven)"
  while true; do
    # inotifyd blocks until configfs event; zero idle CPU
    # c=create, d=delete, e=moved_to
    inotifyd "$HANDLER" "$CONFIG_DIR:cde" >/dev/null 2>&1
    sleep 0.5
  done
else
  log "inotifyd not found, falling back to conditional polling"
  while true; do
    if [ "$(cat /sys/class/power_supply/usb/online 2>/dev/null)" = "1" ] ||
       [ -d "$GADGET/functions/rndis.0" ]; then
      if find_rndis_links | grep -q .; then
        log "RNDIS detected, swapping to NCM..."
        swap_to_ncm
      fi
      sleep 2
    else
      sleep 10
    fi
  done
fi
