use std::process::Command;
use std::str;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    unsafe {
        let fd = libc::socket(
            libc::AF_NETLINK,
            libc::SOCK_RAW | libc::SOCK_CLOEXEC,
            libc::NETLINK_KOBJECT_UEVENT,
        );
        if fd < 0 {
            return Err("Failed to create socket".into());
        }

        let mut addr: libc::sockaddr_nl = std::mem::zeroed();
        addr.nl_family = libc::AF_NETLINK as libc::sa_family_t;
        addr.nl_groups = 1; // Group 1 for uevents
        addr.nl_pid = 0;

        let bind_res = libc::bind(
            fd,
            &addr as *const _ as *const libc::sockaddr,
            std::mem::size_of::<libc::sockaddr_nl>() as libc::socklen_t,
        );

        if bind_res < 0 {
            libc::close(fd);
            return Err("Failed to bind socket".into());
        }

        let mut buf = [0u8; 8192];
        loop {
            let n = libc::read(fd, buf.as_mut_ptr() as *mut libc::c_void, buf.len());
            if n <= 0 {
                continue;
            }

            let msg = str::from_utf8(&buf[..n as usize]).unwrap_or("");

            if msg.contains("SUBSYSTEM=power_supply") {
                if msg.contains("USB_ONLINE=1") || msg.contains("POWER_SUPPLY_ONLINE=1") {
                    // Call service.sh swap_to_ncm
                    let _ = Command::new("/system/bin/sh")
                        .arg("/data/adb/modules/ncm-tether/service.sh")
                        .arg("swap_to_ncm")
                        .spawn();
                }
            }
        }
    }
}
