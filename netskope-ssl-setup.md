# Netskope SSL cert setup (for DGX Spark / other self-hosted HTTPS endpoints)

Netskope's client TLS-inspects outbound HTTPS traffic and re-signs it with its own CA. Any tool
that verifies certs against a standard trust store (`curl`, Python `requests`/`urllib`, etc.)
will reject connections to endpoints behind it — including a self-hosted OpenAI-compatible API
like DGX Spark — unless it's told to trust Netskope's CA chain.

Symptom: `curl` to the endpoint fails with a TLS/cert verification error (e.g.
`SSL certificate problem: unable to get local issuer certificate`), but the same URL works fine
in a browser (browsers usually already trust the Netskope cert installed into the system/login
keychain).

## Steps on a new managed macOS machine

1. **Confirm Netskope client is running and has provisioned certs.** It installs them under:
   ```
   /Library/Application Support/Netskope/STAgent/data/nscacert.pem       # Netskope root/intermediate CA
   /Library/Application Support/Netskope/STAgent/data/nstenantcert.pem  # org/tenant-specific cert, issued by nscacert.pem
   ```
   If you don't know the path on a given machine, find it with:
   ```sh
   find / -iname "*netskope*" -name "*.pem" 2>/dev/null
   find / -iname "*netskope*" -name "*.crt" 2>/dev/null
   ```

2. **Build a combined CA bundle.** Both certs are needed — `nstenantcert.pem`'s issuer is
   `nscacert.pem`, so the full chain must be present for verification to succeed:
   ```sh
   cat "/Library/Application Support/Netskope/STAgent/data/nscacert.pem" \
       "/Library/Application Support/Netskope/STAgent/data/nstenantcert.pem" \
       > ~/.netskope-combined-ca.pem
   ```

3. **Verify** against the target endpoint before wiring it into shell config:
   ```sh
   curl -v --cacert ~/.netskope-combined-ca.pem https://<endpoint>/v1/models \
       -H "Authorization: Bearer <token>"
   ```

4. **Point `SSL_CERT_FILE` at the bundle** so every `curl`/Python call in the shell picks it up
   automatically, without passing `--cacert` each time:
   ```sh
   export SSL_CERT_FILE=~/.netskope-combined-ca.pem
   ```
   In this repo that line lives in `zshrc`, right after `.dgx_secrets` is sourced and before any
   AI function definitions (so it's in effect for all of them).

## Notes / gotchas

- `NODE_EXTRA_CA_CERTS` pointed only at `nscacert.pem` (Netskope's root, no tenant cert) is not
  enough on its own — the tenant cert is what's actually presented mid-chain for org-specific
  endpoints, so leaving it out can still fail chain validation for some tools/endpoints.
- `~/.netskope-combined-ca.pem` and `~/.dgx_secrets` are both untracked (host-specific), so this
  setup needs to be redone by hand on each new machine — there's nothing in `install.sh` that
  automates it.
- If Netskope rotates its CA or tenant cert, regenerate the bundle from the same
  `STAgent/data/` paths.
