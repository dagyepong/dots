─────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
     │ File: virtmanager.py
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ //python 3.13 error with glib2 fix: sudo vim /usr/share/virt-manager/virtManager/virtmanager.py
   2 │
   3 │
   4 │
   5 │     # Actually exit when we receive ctrl-c
   6 │     from gi.repository import GLib, GLibUnix  # <--- Added GLibUnix here
   7 │
   8 │     def _sigint_handler(user_data):
   9 │         ignore = user_data
  10 │         log.debug("Received KeyboardInterrupt. Exiting application.")
  11 │         engine.exit_app()
  12 │
  13 │     GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, _sigint_handler)
  14 │
  15 │     engine.start(options.uri, show_window, domain, skip_autostart)
─────┴───────────────────────