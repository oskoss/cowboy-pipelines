#!/usr/bin/env bash

set -eo pipefail

mkdir -p ~/.pks/
mkdir -p ~/.kube/
cp kube-config/config ~/.kube/config

printf "Creating RBAC Rules for Traefik"

cat << EOF > rbac-config.yaml
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller
subjects:
- kind: ServiceAccount
  name: traefik-ingress-controller
  namespace: kube-system
EOF

kubectl apply -f rbac-config.yaml

printf "Checking for custom TRAEFIK_IMAGE and creating Traefik DaemonSet"

if [[ -z "$TRAEFIK_IMAGE"  ||  "$TRAEFIK_IMAGE" == "null" ]]
then
      echo "No Private traefik Image Specified...using the default traefik"
      export TRAEFIK_IMAGE="traefik"
else
      echo "TRAEFIK_IMAGE Specified as: $TRAEFIK_IMAGE"
fi

cat << EOF > traefik.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
---
kind: DaemonSet
apiVersion: extensions/v1beta1
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress-lb
spec:
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress-lb
        name: traefik-ingress-lb
    spec:
      serviceAccountName: traefik-ingress-controller
      terminationGracePeriodSeconds: 60
      containers:
      - image: $TRAEFIK_IMAGE
        name: traefik-ingress-lb
        ports:
        - name: http
          containerPort: 80
          hostPort: 80
        - name: admin
          containerPort: 8080
        securityContext:
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        args:
        - --api
        - --kubernetes
        - --logLevel=INFO
---
kind: Service
apiVersion: v1
metadata:
  name: traefik-ingress-service
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
    - protocol: TCP
      port: 80
      name: web
    - protocol: TCP
      port: 8080
      name: admin
EOF

kubectl apply -f traefik.yaml

cat << EOF > traefik-dashboard-ingress.yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik-web-ui
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
  - name: web
    port: 80
    targetPort: 8080
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-web-ui
  namespace: kube-system
spec:
  rules:
  - host: $TRAEFIK_INGRESS_DNS
    http:
      paths:
      - path: /
        backend:
          serviceName: traefik-web-ui
          servicePort: web
EOF


kubectl apply -f traefik-dashboard-ingress.yaml

printf "Created Traefik Dashboard Ingress Controller. Traefik Dashboard should now be seen on $TRAEFIK_INGRESS_DNS!!!! \n  ENSURE YOUR DNS HAS A *.$TRAEFIK_INGRESS_DNS A RECORD POINTING TO THE WORKER NODES OF THIS CLUSTER.... "
