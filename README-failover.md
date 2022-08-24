# README Failover

Lets say we have a primary node (`{{Release.Name}}-master-0`) and a couple of standbys. The first standy (`{{Release.Name}}-standby-0`) is a synchronous standby.

For example, `Release.Name` may be something like `postgres-1`, and we have a setup like:

```
   master-0
     -> standby-0 (sync)
     -> standby-1 (async)
```

Say, data PVs (for `$PGDATA`) are assigned as:

| PV          | PVC         |
| ----------- | ----------- |
| `data-X`    | `data-postgres-1-master-0`   |
| `data-Y`    | `data-postgres-1-standby-0`  |
| `data-Z`    | `data-postgres-1-standby-1`  |

Also, Pods have their subfolder (named as the Pod) in the network-shared archive directory (e.g. master will have `archive/postgres-1-master-0`).

## 1. Scenario: Primary node failure

Lets assume primary is down, synchronous standy is up.

### 1.1. Promote first standby

Promote standby-0 to primary (a new timeline is forked):

    kubectl exec -i postgres-1-standby-0 -- su-exec postgres pg_ctl promote

Because the old primary may come up again, ensure that is detached from PgPool (e.g. by using `pcp_detach_node`) so that we dont end up with 2 primaries. Most probably, it will be already detached, as PgPool detects the failover when it looses connection to the primary node. If we had multiple synchronous standbys before, ensure all other standbys (apart from standby-0) are also detached (since now - and for a while - they are not streaming from the new primary)

After a while, PgPool will detect the new primary and will start to use it (as the only backend, since all other backends are detached). Now, the cluster operates in a degraded mode using only standby-0 as the primary node.

### 1.2. Repair

At some time, we must repair the cluster and bring it to the normal mode of operation (where master and standbys operate as they are named for). 
Because the following procedure reassigns PVs, all services must be down. A way to do it is by scaling down to 0 all statefulsets.

#### 1.2.1. Reassign PVs

Reassign PVCs to PVs. If PV `data-X` (bound to master) is inaccessible or corrupted (e.g. as part of the master's failure), then it must be replaced with a new empty directory in a new PV. Otherwise, it may be reused if we rewind it back to the branch point of the new timeline (when standby was promoted). Lets say, `data-X` is unusable so we replace it with `data-W` PV.

So, first, delete PVCs:

    kubectl delete pvc --selector app.kubernetes.io/instance=postgres-1
    
Then, delete PVs at `Released` state (will be recreated):

    kubectl get pv -o name| grep -o 'postgres-1-data-.*'| xargs kubectl delete pv
    
Recreate PVs as below (the easiest way is using `claimRef`s):

| PV          | PVC         |
| ----------- | ----------- |
| `data-Y` (former `standby-0`, promoted)   | `data-postgres-1-master-0`   |
| `data-Z` (former `standby-1`, must rewind on init)   | `data-postgres-1-standby-0`  |
| `data-W` (new, must basebackup on init)   | `data-postgres-1-standby-1`  |

Optional: remember to delete `recovery.done` from data directory `data-Y`.


#### 1.2.2. Rename archive subfolders

Since roles will be changed, archive directories must be renamed accordingly:

Backup former master's archive (just in case):

    mv postgres-1-master-0 postgres-1-master-0.~$(date +%s)

Rename archive of promoted standy (next master):

    mv postgres-1-standby-0 postgres-1-master-0

Rename or create dirs for standbys:

    mv postgres-1-standby-1 postgres-1-standby-0
    mkdir postgres-1-standby-1

#### 1.2.3. Restart cluster with new master

Start cluster:

    helm upgrade postgres-1 postgresql-cluster -f values-local.yaml

When a standby is started (as part of the statefulset), initContainer `prepare-data` will prepare data directory (with `pg_basebackup` or with `pg_rewind`, depending on if data directory is empty) to join the cluster,

If rewind/basebackup is expected to take long, we may start the cluster with asynchronous replication (because the master will wait for the 1st standby). Later, we can switch to synchronous replication without restarting (e.g. with `ALTER SYSTEM SET synchronous_commit TO 'remote_apply'` etc.).  

