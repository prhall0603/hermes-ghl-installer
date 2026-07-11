# SSH Password Authentication via Python PTY

## Problem

Standard `ssh` command with password authentication fails when:
- `sshpass` is not installed
- `PasswordAuthentication=yes` in SSH config still gets rejected
- The remote server requires interactive password entry (no `-p` flag support)

**Error:**
```
Permission denied, please try again.
user@<HOST>: Permission denied (publickey,password).
```

## Solution: Python pty Fork

Use Python's `pty` module to spawn an SSH process with a pseudo-terminal, then
send the password interactively.

```python
import pty, os, select, time

HOST = "user@<HOST>"          # fill in
PASSWORD = os.environ["SSH_PASS"]  # never hardcode — read from env

pid, fd = pty.fork()
if pid == 0:
    os.execvp("ssh", [
        "ssh",
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=10",
        HOST,
        "echo Connected"
    ])
else:
    time.sleep(1)  # Wait for password prompt
    os.write(fd, PASSWORD.encode() + b"\n")
    time.sleep(2)

    output = b""
    while True:
        ready, _, _ = select.select([fd], [], [], 2)
        if not ready:
            break
        try:
            chunk = os.read(fd, 4096)
            if not chunk:
                break
            output += chunk
        except OSError:
            break

    text = output.decode('utf-8', errors='replace')
    # Filter password prompt from output
    lines = [l for l in text.split('\n')
             if 'password:' not in l.lower() and l.strip()]
    print('\n'.join(lines))
```

## Running Remote Commands

For each command, fork a new pty process (SSH sessions don't persist across pty
forks). Read the password from an environment variable, never a literal.

## Important Notes

- **Each command needs a fresh fork** — SSH sessions don't persist across pty forks
- **Password is sent in plaintext** over the PTY — this is fine over an encrypted
  tunnel (Tailscale/WireGuard, local LAN), but never use over the public internet
- **Never hardcode the password** — read it from an env var or a `chmod 600` file
- **Filter output** — always strip `password:` prompts and ANSI escape sequences
  from captured output before presenting to the user
- **apt lock contention** — if running multiple apt commands in sequence, the
  second may fail with "Could not get lock /var/lib/dpkg/lock-frontend". Combine
  into a single SSH session: `sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y`
- **Alternative:** Install `sshpass` (`sudo apt-get install sshpass`) for cleaner
  password handling, but it may not be available in all environments
- **Timing for different commands:**
  - Simple commands (uptime, df, tailscale version): 2-3 seconds
  - Package operations (apt update): 5-15 seconds
  - System upgrades (apt upgrade -y): 25-60+ seconds

## When This Applies

- Raspberry Pi maintenance over Tailscale
- Any remote Linux server where key-based auth isn't configured
- Embedded devices (Pi, NAS, router) that only have password auth
- Docker containers or VMs in local networks

## Security Note

This method is for **automation of trusted infrastructure** over encrypted
channels (Tailscale, WireGuard, local LAN). For production servers exposed to the
internet, use SSH key authentication instead.
