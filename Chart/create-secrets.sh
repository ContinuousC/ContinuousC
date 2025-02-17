#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <namespace>" >&2
    exit 1
fi

namespace="$1"
secrets="$HOME/.continuousc-$namespace.json"
stamp="$HOME/.continuousc-$namespace.stamp"

if ! [ -f "$secrets" ]; then
    touch "$secrets"
    chmod u=rw,og= "$secrets"

    opensearch=$(pwgen -s1 64)

    cat > "$secrets" <<EOF
   {
     "grafana-admin-user": "admin",
     "grafana-admin-password": "$(pwgen -s1 64)",
     "opensearch-admin-password": "$opensearch",
     "opensearch-admin-hash-password": "$(htpasswd -bnBC10 '' $opensearch | sed -rne 's/^:(.+)$/\1/p')",
     "postgresql-pgpool-admin-password": "$(pwgen -s1 64)",
     "postgresql-postgres-password": "$(pwgen -s1 64)",
     "postgresql-repmgr-password": "$(pwgen -s1 64)",
     "postgresql-user-password": "$(pwgen -s1 64)"
   }
EOF
    echo "Generated new secrets in $secrets"
fi

if [ "$secrets" -nt "$stamp" ]; then
    echo "Updating secrets"
    vault kv put -mount=kv "continuousc/$namespace" "@$secrets"
    touch $stamp
else
    echo "Secrets are up-to-date"
fi
