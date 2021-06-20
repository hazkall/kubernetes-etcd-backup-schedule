#!/bin/bash

set -ex

if [ ! -d /opt/kubernetes/backup ];
    then
        mkdir -p /opt/kubernetes/backup
fi

read -p "Do you wish to backup ETCD now or schedule? (answer: now or schedule)" yn
    case $yn in
        now) backup-now;;
        schedule) schedule ;;
        *) echo "Please answer now or schedule.";;
    esac


function backup-now() {

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

    if [ -f /var/lib/etcd/snapshot.db ];
        then
            cp /var/lib/etcd/snapshot.db /opt/kubernetes/snapshot.db-$(date +%m-%d-%y)
            cp -r /etc/kubernetes/pki/etcd /opt/kubernetes/etcd-$(date +%m-%d-%y)
    fi

    return ls -lha /opt/kubernetes/

} 

function schedule () {

    kubectl apply -f etcd-backup-job.yaml

    if [[ $(kubectl get cronjobs.batch -n kube-system -o=jsonpath={'..spec.schedule'}) == "* * * * *" ]];
        then 
            echo "WARNING! This schedule time can broke your etcd backup" 
            kubectl get cronjobs.batch -n kube-system
    else
            echo '#!/bin/bash' >> /etc/cron.weekly/snapshot.sh
            echo 'if [ -f /var/lib/etcd/snapshot.db ];then cp /var/lib/etcd/snapshot.db /opt/kubernetes/backup/snapshot.db-$(date +%m-%d-%y);fi' >> /etc/cron.weekly/snapshot.sh
            echo 'if [ -f /var/lib/etcd/snapshot.db ];then cp -r /etc/kubernetes/pki/etcd /opt/kubernetes/backup/etcd-$(date +%m-%d-%y);fi' >> /etc/cron.weekly/snapshot.sh
            
            kubectl get cronjobs.batch -n kube-system
    fi
}