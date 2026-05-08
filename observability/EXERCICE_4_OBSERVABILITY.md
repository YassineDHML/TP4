# PARTIE 2 : Observabilité (Prometheus & Grafana)

Vous avez maintenant une application conteneurisée déployée automatiquement sur votre cluster Kubernetes local ! Voici comment mettre en place la stack complète de surveillance (Prometheus + Grafana) via Helm.

## Étape 1 : Installation de la stack via Helm

Assurez-vous d'avoir `helm` installé. Dans votre terminal, exécutez ces commandes en pointant vers votre cluster `Kind` (via le fichier kubeconfig généré à la racine) :

```bash
# Exporter la variable KUBECONFIG pour que helm trouve votre cluster local
$env:KUBECONFIG="C:\Users\Yassine\Desktop\DevOps-TP\TP4\kubeconfig"

# Ajouter le dépôt de la communauté Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Installer kube-prometheus-stack
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

Patientez 2 ou 3 minutes que tous les pods du namespace `monitoring` soient bien lancés : `kubectl get pods -n monitoring`.

## Étape 2 : Exposer Grafana

Pour accéder au dashboard Grafana fourni par défaut, transférez le port en local :

```bash
kubectl port-forward svc/monitoring-grafana 8080:80 -n monitoring
```

* **URL :** `http://localhost:8080`
* **Utilisateur :** `admin`
* **Mot de passe :** `prom-operator`

## Étape 3 : Configurer la remontée de nos métriques (ServiceMonitor)

L'application expose `/metrics`. Pour que Prometheus les "scrape", nous devons appliquer un `ServiceMonitor`. 
Vous pouvez appliquer ce fichier `servicemonitor.yaml` que nous avons préparé :

```bash
kubectl apply -f observability/servicemonitor.yaml
```

## Étape 4 : Création du Dashboard Grafana

1. Allez dans Grafana (http://localhost:8080).
2. Cliquez sur **Dashboards** > **New Dashboard** > **Import**.
3. Plutôt que de tout construire de zéro, vous pouvez utiliser un panel basique ou taper la requête PromQL suivante dans un "Time series" Pannel :
   - *Trafic entrant (requêtes HTTP) :* `rate(http_requests_total[5m])`
   - *CPU de notre Pod :* `sum(rate(container_cpu_usage_seconds_total{pod=~"tp4-app-.*"}[5m]))`

## Étape 5 : Configuration de l'AlertManager

Nous pouvons insérer une règle pour déclencher une alerte si l'application devient injoignable pendant 2 minutes. Appliquez le fichier d'alerte préparé :

```bash
kubectl apply -f observability/alertrule.yaml
```

Pour tester l'alerte, vous pourrez simuler une panne en détruisant votre déploiement ou en limitant ses réplicas à 0 :
```bash
kubectl scale deployment tp4-app --replicas=0
```
Dans Grafana (section Alerting) ou Prometheus, l'alerte "ApplicationDown" passera en rouge après 2 minutes.
