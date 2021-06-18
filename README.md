Spark History Server Helm Chart
===============================

 A helm chart for deploying the Spark History Server to Kubernetes 
using S3 Object Storage for Spark EventLogs. Some of the existing 
charts do not account for the S3 requirements.


## Configuration

The chart takes a few primary config parameters; other options 
can be customized by adjusting the values file.

|     Option     | Description |
| -------------- | ----------- |
|  s3endpoint    | The S3 Endpoint URL, eg. *http://minio-svc:9000* |
| s3logDirectory | The path to s3 bucket, eg. s3a://spark/spark-logs |
|  s3accessKey   | The S3 Access Key |
|  s3secretKey   | The S3 Secret Key |

- *s3endpoint* in the format of `http://minio-svc:9000`
- *s3logDirectory defines the bucket path, which should be a path at 
  least one level below the root. ie. `s3a://spark/spark-logs`


<br>


## Install the Helm Chart

Config parameters can be added to a custom version of *values.yaml* and 
passed to helm via `-f myvalues.yaml` or via the `--set` directive.

A service account for spark should be created either ahead of time or set
*serviceAccount.create* as *true* in the `values.yaml` file.
```
  kubectl create namespace spark
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


## Uninstall Chart

Simply use helm to remove the deployment
```
helm uninstall --namespace spark spark-hs
```


## Accessing the UI

By default the Service is using *ClusterIP*. Typically, we add an ingress 
gateway and use *LoadBalancer*. 

A quick validation would be to port-forward the history server port.
```bash
# get pod name and service port
relname="spark-hs"
ns="spark"

POD_NAME=$(kubectl get pods -n $ns | grep $relname | awk '{ print $1 }')
HS_PORT=$( kubectl get service $relname -n $ns -o=json | jq .spec.ports[0].port )

# port forward
kubectl port-forward $POD_NAME $HS_PORT --namespace $ns &
```

If the service type was set to NodePort, acquire the Application URL
```bash
export NODE_PORT=$(kubectl get --namespace spark -o jsonpath="{.spec.ports[0].nodePort}" services spark-hs)
export NODE_IP=$(kubectl get nodes --namespace spark -o jsonpath="{.items[0].status.addresses[0].address}")
echo http://$NODE_IP:$NODE_PORT
```

---

## Using ArgoCD to deploy a helm chart

An Argo *Application* yaml as in *argo/spark-hs-argo.yaml* which defines
the required chart values. The argo app sets secrets through environment vars 
which shold be set prior to deploying. The yaml provided expects *MINIO_ENDPOINT*, 
*MINIO_ACCESS_KEY*, and *MINIO_SECRET_KEY* to already be configured.

To deploy to ArgoCD, parse the yaml through `envsubst` and send to `kubectl create`. 
```
  export MINIO_ENDPOINT="https://minio.mydomain.internal:9000"
  export MINIO_ACCESS_KEY="myaccesskey"
  export MINIO_SECRET_KEY="mysecretkey"
  cat argo/spark-hs-argo.yaml | envsubst | k create -f -
```
