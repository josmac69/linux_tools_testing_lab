`coredumpctl` ships in the `systemd-coredump` package on Debian:

```bash
sudo apt install systemd-coredump
```

Installing it also switches the kernel's `core_pattern` to pipe crashes into systemd-coredump (verify with `cat /proc/sys/kernel/core_pattern` — it should show `|/lib/systemd/systemd-coredump ...`), after which `coredumpctl list` works.

It only captures crashes from the moment it's installed onward.


