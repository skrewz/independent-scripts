# Sign and timestamp-sign contents of folders

This script iterates through the contents of a folder you give it, GPG detach-signs each file, and interrogates time stamping authorities on the Internet to prove that the signature existed as-of now.

This gives a convenient way to prove that you know certain things at certain times, without revealing what those things are.

# Use cases
It's kind of open-ended. Anything that you need to prove a "knew before time" statement on.

- A receipt collection
- Photo folder
- `offlineimap`-sync'ed emails

# Known issues

- Currently the change-detection mechanism is that of sha256'ing the contents of all affected files. That is a lot of disk activity, and a lighter-touch `--use-timestaps` option should be introduced.
- More TSA's should be introduced. Currently, it's only freetsa.org.

