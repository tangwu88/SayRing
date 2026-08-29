# Saidian local patch

This directory is a source copy of `jpush_flutter` version `3.5.1`.

The Android plugin originally logged the complete `setup` argument map. That
map contains the configured JPush AppKey even when SDK debug mode is disabled.
The local patch keeps the same package and native SDK versions, but replaces
that log with a parameter-free setup marker.

Keep this path override until the upstream plugin removes the argument log.
