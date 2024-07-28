# What and why
Tailscale (and, by extension, headscale) operates a tiny DNS server that resolves hosts on your tailnet. This feature is called MagicDNS.

Despite the name, it isn't altogether magical. 'Magic' DNS only supports A, AAAA and CNAME records and does not support wildcards. 

`mundanedns` (`mundane` being the opposite of `magic`) generates entries for a local `/etc/hosts` file to achieve the same result as tailscale's MagicDNS but without using tailscale DNS settings. Relying on Tailscale DNS may be undesireable where, for instance, you're running a DNS server on your LAN for ad blocking or lower latency. 

The hosts file has the same limitations as MagicDNS: no wildcards, no extra record types. For that, you'd want to integrate your tailnet zone into your existing DNS server setup (something on my personal TODO list).

# How it works
`tailscale status --json` prints out a lot of useful information about the tailnet, including the hostnames and IP addresses of each node on the tailnet. `mundanedns` will parse this information and format it for use in a hosts file. To avoid unnecessary updates, `mundanedns` saves a hash of the status in the current working directory and won't run if the hash hasn't changed. All that's left is to run `mundanedns` with the desired level of regularity. 

# Features / TODO
- [x] Powershell Script to do this on Windows.
- [ ] Bash script to do this on Linux.
- [ ] Bash, python, or 💡 DNSControl script to write proper zonefiles

# Scheduling
## On Windows

To run `mundanedns.ps1` with admin privileges every ~hour, pull up Task Scheduler and:

1. Click on "Create Basic Task" in the Actions pane on the right.
2. Give your task a name and click "Next".
3. Choose the trigger "Daily" (yes, daily, Windows is 💩).
4. Select the start date and time for your task. 
5. Choose "Start a program" as the action and click "Next".
6. Point the "Program/script" field to the path of your `pwsh` executable, such as `"C:\Program Files\PowerShell\7-preview\pwsh.exe"` or `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`.
7. In the "Add arguments" field, enter the relative path to your PowerShell script (e.g., `. .\mundanedns.ps1`).
8. Set the correct working directory.
9. Click through to the last screen and tick the box for "Show Properties after I click finish".
10. In the properties window, tick "Run with highest privileges".
11. In the Triggers tab, find your daily trigger and edit it to repeat every hour (yes, I know, Windows).

This may or may not be the best solution for you. You might want to change the permissions on `/etc/hosts` to allow your user account write-access, you might use a more frequent interval... that is up to you.

Do note that if you add nodes to your tailnet, they won't magicaly show up, so just run the script manually.
