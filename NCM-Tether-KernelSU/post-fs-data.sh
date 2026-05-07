#!/system/bin/sh
# NCM Tether - Early setup
# Runs before most services start

MODDIR=${0%%/*}

# Create a marker file so service.sh knows module is active
touch /data/local/tmp/ncm-tether-active
