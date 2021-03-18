Spark History Server Helm Chart
===============================

 A helm chart for deploying the Spark History Server to Kubernetes 
using S3 Object Storage for Spark EventLogs. Some of the existing 
charts do not account for the S3 requirements.


## Configuration

The chart takes a few primary config parameters; other options 
can be customized by adjusting the values file.

| Option  | Description |
| ------- | ----------- |
| s3endpoint | The S3 Endpoint URL, eg. *http://minio-svc:9000* |
| s3logDirectory | The path to s3 bucket, eg. s3a://spark/spark-logs |
| s3accessKey | The S3 Access Key |
| s3secretKey | The S3 Secret Key |

<br>

## Install the Helm Chart

Config parameters can be added to a custom version of *values.yaml* and 
passed to helm via `-f myvalues.yaml` or via the `--set` directive.

A service account for spark should be created either ahead of time or set
*serviceAccount.create* as *true* in the `values.yaml` file.
```
  kubectl create serviceaccount spark --namespace spark

  kubectl create clusterrolebinding spark-rolebinding \
    --clusterrole=edit \
    --serviceaccount=spark:spark \
    --namespace=spark
```

Install by values file
```
$ helm install -f <myvalues.yaml> --namespace <ns> <release-name> <path_to_chart>
```

for example:
```
$ helm install -f callisto-values.yaml --namespace spark spark-hs .
```

Alternatively, install via helm command-line.
```
helm install --set app.s3logDirectory=s3a://mybucket/eventLogs/,app.s3endpoint=http://endpoint:9000,s3accessKey=xxxxxx,app.s3secretKey=xxxxx --namespace spark spark-hs .
```

## Uninstall 

Simply use helm to remove the deployment
```
helm uninstall --namespace spark spark-hs
```

## Accessing the UI

By default the Service is using *ClusterIP*. Typically, we add an ingress gateway
and use *LoadBalancer*. 

A quick validationwould be to port-forward the history server port.
```bash
relname="spark-hs"
ns="spark"

POD_NAME=$(kubectl get pods -n $ns | grep $relname | awk '{ print $1 }')
HS_PORT=$( kubectl get service $relname -n $ns -o=json | jq .spec.ports[0].port )

kubectl port-forward $POD_NAME $HS_PORT --namespace $ns &
```

