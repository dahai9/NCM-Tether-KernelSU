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

# Main loop - conditional polling
# USB disconnected: sleep 30s (near-zero CPU)
# USB connected: sleep 3s (fast enough to catch RNDIS before tethering stabilizes)
log "Starting conditional polling"
while true; do
  if [ "$(cat /sys/class/power_supply/usb/online 2>/dev/null)" = "1" ] ||
     [ -d "$GADGET/functions/rndis.0" ]; then
    if find_rndis_links | grep -q .; then
      log "RNDIS detected, swapping to NCM..."
      swap_to_ncm
    fi
    sleep 3
  else
    sleep 30
  fi
done
