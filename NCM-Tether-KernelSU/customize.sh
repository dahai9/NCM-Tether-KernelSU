#!/system/bin/sh
# NCM Tether module installation script

# Check for ncm.0 function support
if [ ! -d /config/usb_gadget/g1/functions/ncm.0 ]; then
  abort "! ncm.0 function not found on this device"
fi

ui_print "- Device supports ncm.0 USB function"
set_perm $MODPATH/bin/uevent-listener 0 0 0755
ui_print "- NCM Tether module will activate on reboot"
