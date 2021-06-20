# Backup ETCD Script

## Objetive

Run ETCD backup in this time or schedule a ETCD backup using CRONJOB on kubernetes.

## Configure CRONJOB

Inside the manifest of cronjob you can change the schedule date on spec.schedule

Its important to use the correct sintax of time.

refer -> <https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/>

```yaml

apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-etcd
  namespace: kube-system
spec:
  schedule: 30 14 * * 3 # -------> This field you can costumize the schedule time to run the job on kubernetes” 
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: kubectl-backup
          containers:
          - name: backup-etcd
            image: bitnami/kubectl
            imagePullPolicy: IfNotPresent
            command:
              - /bin/bash
              - -c
              - |
                kubectl exec -n kube-system \
                $(kubectl get pod -n kube-system \
                -o=jsonpath='{.items[*].metadata.name}' | \
                sed 's/[[:space:]]/\n/g' | \
                grep '^etcd') -- sh -c "ETCDCTL_API=3 \
                ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt \
                ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt \
                ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key \
                etcdctl --endpoints=https://127.0.0.1:2379 \
                snapshot save /var/lib/etcd/snapshot.db"
          restartPolicy: OnFailure

```

## Execute the script

```sh

sudo chmod +x backup.sh
sudo ./backup.sh

```