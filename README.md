Spark History Server Helm Chart
===============================

## Config

The chart takes the following config parameters:

| Option  | Description |
| ------- | ----------- |
| s3endpoint | The S3 Endpoint URL, eg. *http://minio-svc:9000* |
| s3logDirectory | The path to s3 bucket, eg. s3a://spark/spark-logs |
| s3accessKey | The S3 Access Key |
| s3secretKey | The S3 Secret Key |

---

## Install

Config parameters can be added to a custom version of *values.yaml* and 
passed to helm via `-f myvalues.yaml` or passed via the `--set` directive.

Install by values file
```
$ helm install -f <values.yaml> --namespace <ns> <release-name> <path_to_chart>
```

for example:
```
$ helm install -f callisto-values.yaml --namespace spark spark-hs .
```

Alternatively, install via helm command-line
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

A quick test would be to port-forward the history server port.
```bash
RELEASE_NAME="spark-hs"
POD_NAME=$(kubectl get pods -n spark | grep $RELEASE_NAME | awk '{ print $1 }')
PORT=18080

kubectl port-forward $POD_NAME $PORT --namespace spark &
```