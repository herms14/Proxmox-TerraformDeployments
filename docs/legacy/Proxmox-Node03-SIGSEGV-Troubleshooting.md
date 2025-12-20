# Proxmox Corosync Crash (SIGSEGV) on node03

**Root Cause Analysis, Diagnosis, and Resolution**

## Summary

`corosync` on **node03** repeatedly crashed with **SIGSEGV (segmentation fault)** during startup.  
Because Proxmox clustering depends on Corosync, this prevented the node from functioning correctly in the cluster.

In simple terms: **the cluster heartbeat service was crashing immediately**, so node03 could not reliably communicate with the other nodes.

---

## Symptoms Observed

### Corosync would not start

Repeated errors:

- `Failed to start corosync.service`
    
- `status=11/SEGV`
    
- Logs stopped at: `Initializing transport (Kronosnet)`
    

This tells us Corosync started, reached the networking layer, and then crashed hard.

### Reinstalling Corosync alone did not fix it

Packages such as:

- `corosync`
    
- `libknet`
    
- `libnozzle`
    
- `libqb`
    

were reinstalled multiple times with **no change**.

This strongly suggests the issue was **not**:

- a bad `corosync.conf`
    
- missing `authkey`
    
- permission issues
    

Instead, it pointed to a **runtime dependency failure**.

---

## Understanding the Error (Beginner-Friendly)

### What SIGSEGV means

SIGSEGV (Segmentation Fault) means:

> A program tried to access memory it was not allowed to use.

This usually happens due to:

- corrupted libraries
    
- incompatible library versions
    
- plugin / dependency mismatches
    

This is not a configuration typo — it’s a **binary-level crash**.

---

## Diagnostic Process

### Step 1 — Validate the configuration

Running:

`corosync -t`

Result:

- Exited normally
    
- No syntax errors
    

Conclusion:

- The configuration file was valid
    
- The crash happens during **runtime initialization**, not config parsing
    

---

### Step 2 — Enable and collect a core dump

Initially `coredumpctl` was unavailable, so the following were installed:

- `systemd-coredump`
    
- `gdb`
    
- `strace`
    

After Corosync crashed again:

`coredumpctl info corosync`

This produced a full stack trace.

---

### Step 3 — Analyze the stack trace (the breakthrough)

The crash occurred inside:

- `PK11_CipherOp` → `libnss3.so`
    
- Called from `crypto_nss.so`
    
- Loaded by `libknet.so`
    
- Invoked by `corosync`
    

**Plain-language translation:**

Corosync uses:

- **kronosnet (knet)** for cluster networking
    
- knet loads a crypto plugin (`crypto_nss`)
    
- that plugin relies on **NSS crypto libraries (`libnss3`)**
    

The crash happened **inside the crypto engine**, not the network or config logic.

---

## Root Cause

**A broken or mismatched NSS crypto stack (`libnss3`) caused Corosync to segfault during encrypted cluster transport initialization.**

This explains why:

- wiping `/var/lib/corosync`
    
- changing `ip_version`
    
- disabling IPv6
    
- toggling `link_mode`
    

had **zero effect** — the failure happened before networking logic fully initialized.

---

## Why IPv6 Was Not the Problem

Although IPv6 was disabled and `ip_version: ipv4` was set:

- The crash stack showed failure inside **encryption code**
    
- Not routing, not sockets, not IP negotiation
    

IPv6 was a reasonable hypothesis — but ultimately a red herring.

---

## Resolution (What Actually Fixed It)

### Key Fix

Reinstall the **entire crypto and transport dependency chain together**:

- `libnss3`
    
- `libnss3-tools`
    
- `libknet1t64`
    
- `libnozzle1t64`
    
- `corosync`
    
- `libcorosync-common4`
    

This repaired:

- corrupted shared objects
    
- mismatched crypto plugins
    
- broken NSS function calls
    

After reinstall:

`systemctl start corosync`

✅ Success — no segfault

---

## Verification

### Corosync health

- Service state: `active (running)`
    
- Log confirmed:
    
    - `crypto_nss.so has been loaded successfully`
        

### Cluster filesystem (pmxcfs)

`systemctl start pve-cluster`

- Cluster config synced
    
- Corosync config propagated correctly
    

### Cluster quorum

`pvecm status`

Results:

- Nodes: 3
    
- Expected votes: 4 (QDevice + nodes)
    
- Quorum: 3
    
- **Quorate: Yes**
    

Cluster fully restored.

---

## Mental Model (Easy Way to Remember This)

Think of Proxmox clustering like a secure group call:

- **Corosync** → the call application
    
- **knet/kronosnet** → the transport
    
- **crypto_nss plugin** → encryption adapter
    
- **libnss3** → crypto engine
    

Your **crypto engine was broken**, so encryption crashed, killing the transport and the app.

Reinstalling `libnss3` fixed the engine.  
Reinstalling knet + corosync ensured compatibility.

---

## Prevention & Best Practices

### Keep nodes package-consistent

Run regularly on **all nodes**:

`apt update apt full-upgrade -y pveversion -v`

### Avoid partial upgrades

Crypto libraries are especially sensitive to version mismatches.

### Future crash playbook

If Corosync crashes again:

1. Check logs:
    

`journalctl -xeu corosync`

2. Inspect core dump:
    

`coredumpctl info corosync`

3. If crypto-related:
    

`apt install --reinstall -y \   libnss3 libnss3-tools \   libknet1t64 libnozzle1t64 \   corosync libcorosync-common4`

---

## Appendix: corosync.conf (totem section)

Your configuration is valid and secure:

- `crypto_cipher: aes256`
    
- `crypto_hash: sha256`
    
- `ip_version: ipv4`
    
- `secauth: on`
    

Configuration correctness was **not** the issue — the runtime crypto library was.