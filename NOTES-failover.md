# quick notes for failover procedure

Say we have a cluster of 2 nodes:

```
   postgres-1-master-0
     -> postgres-1-standby-0 (sync)
```

This is for the case of primary server failure. So, `postgres-1-master-0` has failed completely (data directory is not even accessible).

Steps for failover to standby (promotion):

## 1. stop standby server

Uninstall the Helm chart

## 2. prepare PV of standby

Create a debug pod mounting standby's data. Clear files:
 - `standby.signal`
 - `01-cluster-name.conf`

## 3. rename PVC

Rename PVC of master data (possibly inaccessible now) to a backup (just in case we need a later investigation):
   `data-postgres-1-master-0` -> `data-postgres-1-master-0-backup-$(date +%s)`

Rename PVC of standby data (using the `rename-pvc` Krew plugin, or manually by manipulating claimRefs):
   `data-postgres-1-standby-0` -> `data-postgres-1-master-0`

## 4. rename subfolders of archive NFS dir 

Create a debug pod mounting the archive dir. Rename subfolders (named as respective database pods).

Backup former master's archive (just in case):

    mv postgres-1-master-0 postgres-1-master-0.~$(date +%s)

Rename archive of promoted standy (next master):

    mv postgres-1-standby-0 postgres-1-master-0

## 5. start

Reinstall the Helm chart
