# Investigation

# List boots
```
root@josefm-lin-0:/home/josef# journalctl --list-boots
IDX  BOOT ID                          FIRST ENTRY                  LAST ENTRY

  -8 3b56e658e85b4d5ba572797021a9ba1a Sat 2026-07-11 22:14:30 CEST Sun 2026-07-12 05:52:53 CEST
  -7 7a24d2a49ec8493a86c5b49ba09fe001 Sun 2026-07-12 11:07:49 CEST Sun 2026-07-12 13:20:27 CEST
  -6 b3fbcaacf5ec402388060ec4d984abd6 Mon 2026-07-13 09:12:04 CEST Mon 2026-07-13 17:44:41 CEST
  -5 e94ce9b17c364f65a41a8b045a0c170a Mon 2026-07-13 18:02:05 CEST Mon 2026-07-13 21:25:44 CEST
  -4 50baa600ffff478a88ec68a4edb3b78d Tue 2026-07-14 08:46:54 CEST Tue 2026-07-14 17:53:59 CEST
  -3 eab2a18a70524ae39a8db3960ca8afbc Tue 2026-07-14 19:40:49 CEST Wed 2026-07-15 00:25:09 CEST
  -2 58b661d742834fada73a4118591ad988 Wed 2026-07-15 09:03:40 CEST Wed 2026-07-15 12:19:15 CEST
  -1 fec1cc963c7244b3b06294379330d1fa Wed 2026-07-15 12:20:11 CEST Wed 2026-07-15 13:42:39 CEST
   0 22fc8bd650b2428bbdfcac9bba71a72e Wed 2026-07-15 13:58:34 CEST Wed 2026-07-15 14:28:45 CEST
```

variants of the command:
```
journalctl --list-boots --no-pager|tail -n 10
```

# List records for particular boot
```
journalctl -b -2 --no-pager|less

Jul 15 12:19:15 josefm-lin-0.credativ.de dockerd[2220]: time="2026-07-15T12:19:15.904870168+02:00" level=error msg="Error running exec 8c757760aa8dbdca569a32b75553afcb26ed7a86a7cfde8b2b8cbcbdab16b64f in container: exec attach failed: error attaching stderr stream: write unix /run/docker.sock->@: write: broken pipe"
```


