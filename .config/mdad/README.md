# MDAD local configuration

This directory is the tracked, secret-free source for Evie's
`matrix-docker-ansible-deploy` configuration.

- `matrix.cloudhub.social/vars.yml` contains ordinary editable Ansible values
  and BSM environment lookups, never secret values.
- `matrix.cloudhub.social/secret-keys.txt` is the allowlist of BSM objects that
  `~/.local/bin/matrix-ansible-bsm` may inject into an Ansible process.
- The BSM project is `MDAD` (`7d21a45b-e63a-4177-9020-b48701662eda`).
- The playbook inventory path is a local symlink to the tracked `vars.yml`.

Edit configuration normally at either path:

```sh
$EDITOR ~/.config/mdad/matrix.cloudhub.social/vars.yml
$EDITOR ~/git/matrix-docker-ansible-deploy/inventory/host_vars/matrix.cloudhub.social/vars.yml
```

Run every playbook command through the BSM injector so missing secrets fail
closed and never enter the tracked file:

```sh
matrix-ansible-bsm -- just install-all
matrix-ansible-bsm -- ansible-playbook -i inventory/hosts setup.yml --syntax-check
```

Adding or rotating a secret is a deliberate BSM operation: update the object in
the `MDAD` project, add its key to `secret-keys.txt` when new, and reference it
from `vars.yml` with `lookup('ansible.builtin.env', ..., default=undef())`.
