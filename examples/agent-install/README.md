# Install the agent on many servers

The InfraNest agent reports CPU, memory, disk, load and service health from Linux and Windows servers. It only ever
sends: it takes no instructions, runs no commands, opens no ports, and runs as its own unprivileged user. Its source
is in [infranest-agent](https://github.com/InfraNest-Infrastructure-Organized/infranest-agent).

This folder installs it the same way as the one-line install in the app, on many servers at once.

Docs: [Install the agent on many servers](https://developers.infranest.io/agent/install-on-many-servers)

| File | What it is |
|---|---|
| [`roles/infranest_agent/`](roles/infranest_agent/) | An Ansible role for Linux and Windows hosts. A host that already has the agent is left alone |
| [`site.yml`](site.yml) | A playbook that applies the role to every host in the inventory |
| [`inventory.example.yml`](inventory.example.yml) | An example inventory, Linux and Windows hosts |
| [`cloud-init.yaml`](cloud-init.yaml) | User data that installs the agent on a new Linux server's first boot |

## One key for every server

Create an **enrollment key** under **Settings → Server agent → New key** in InfraNest. It starts with `sek_` and
is shown once. Give it an expiry or a maximum number of servers if you want to bound it. The installer trades the
key for **that server's own token** before it installs anything, so the agent never sees the key: revoking the key
stops new installs, and every server that already enrolled keeps reporting. Running it again on the same machine
gets the same server back instead of adding one.

You can still give each server its own token instead, from its page in InfraNest (**Metrics → Install agent**). It
starts with `sat_`.

## Ansible

Put the key in `group_vars/all.yml`, encrypted:

```sh
cp inventory.example.yml inventory.yml     # list your servers
mkdir -p group_vars
ansible-vault encrypt_string 'sek_…' --name infranest_enrollment_key > group_vars/all.yml
ansible-playbook -i inventory.yml site.yml --ask-vault-pass --check   # see what it would do
ansible-playbook -i inventory.yml site.yml --ask-vault-pass
```

The key is passed with `--enroll` / `-Enroll`, and the task's log is suppressed so it never appears in Ansible's
output. To use a token per server instead, leave `infranest_enrollment_key` empty and put each server's token in
its `host_vars` file (`ansible-vault encrypt_string 'sat_…' --name infranest_agent_token`); the token is then
written to a file only root (or the administrators, on Windows) can read and passed with `--token-file` /
`-TokenFile`. The installer, and any token file, are removed afterwards. Set `infranest_agent_processes: true` to
also report the busiest processes by name (program names only, never their arguments).

Windows hosts need the `ansible.windows` collection, which comes with the `ansible` package.

## cloud-init

Paste [`cloud-init.yaml`](cloud-init.yaml) into your cloud provider's *user data* field, or pass it to the API or
Terraform that creates the server, with `sek_YOUR_KEY` replaced by your enrollment key. The same file works for
every server. Anyone who can read the instance's configuration at your cloud provider can read the key too, so give
it an expiry or a server limit if that is wider than you want.

## Check it worked

```sh
sudo infranest-agent status
```

The server shows live metrics in InfraNest within a minute. `infranest-agent print` shows the exact JSON it would
send, and sends nothing.

## What CI checks, and what it does not

This example installs software on servers, so CI never runs it for real, and it does not use the sandbox. On every
pull request and once a week CI runs `ansible-lint`, checks the playbook's syntax, runs the playbook in `--check`
mode against the CI machine itself (which installs nothing), and checks that `cloud-init.yaml` is valid YAML with a
`#cloud-config` header. Try it on one test server before you roll it out.
