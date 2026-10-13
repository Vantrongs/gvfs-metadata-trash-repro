# gvfsd-metadata: emptying a large trash

Reproduction for a GNOME/gvfs issue: after the trash holding a directory of N files is emptied, gvfsd-metadata stays at 100% CPU for a time that grows with N².

```sh
./run.sh 20000
./run.sh 40000
```

Each run prints how long the files took to delete and how long gvfsd-metadata stayed busy afterwards. Output of `./run.sh 20000` with gvfs 1.60.3:

```
files: 20000
files deleted after: 0.4 s
gvfsd-metadata busy for: 4.8 s (CPU 4.8 s)
Remove calls received: 20002
AttributeChanged signals: 20005
peak RSS: 37 MiB
```

`run.sh` starts a private session bus with a throwaway `HOME` under `/tmp`, so the gvfsd, gvfsd-trash and gvfsd-metadata it activates never see your real trash or metadata. `empty-trash.sh` refuses to run outside that setup and refuses to empty the trash if it holds anything but the test directory.

Needs `gio`, `gdbus`, `dbus-run-session`, `dbus-monitor` and `bc`. The gvfs GIO module must be loadable by `gio`: distributions install it in GIO's default module directory; on NixOS, set `GIO_EXTRA_MODULES=<gvfs>/lib/gio/modules`.
