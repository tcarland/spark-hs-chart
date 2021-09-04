Spark History Server Helm Chart
===============================

 A helm chart for deploying the Spark History Server to Kubernetes 
using S3 Object Storage for Spark EventLogs. Some of the existing 
charts do not account for the S3 requirements.

<br>

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

Install by a values file
```
$ helm install -f <myvalues.yaml> --namespace <ns> <release-name> <path_to_chart>
```

for example:
```
$ helm install -f callisto-values.yaml --namespace spark spark-hs .
```

Alternatively, install via helm command-line.
```
helm install --create-namespace --set \
s3endpoint=${S3_ENDPOINT},\
s3accessKey=${S3_ACCESS_KEY},\
s3secretKey=${S3_SECRET_KEY},\
s3logDirectory=s3a://spark/spark-logs,service.type=LoadBalancer \
service.type=LoadBalancer \
--namespace spark \
spark-hs .
```

The github also acts as our chart repository.
```
helm repo add spark-hs-chart https://tcarland.github.io/spark-hs-chart/
helm install spark-history-server spark-hs-chart/spark-hs \
 --create-namespace --set [options] --namespace spark
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
echo https://$NODE_IP:$NODE_PORT
```

---

## Using ArgoCD to deploy a helm chart

An Argo *Application* yaml as in *argo/spark-hs-argo.yaml* which defines
the required chart values. The argo app sets secrets through environment vars 
which shold be set prior to deploying. The yaml provided expects *S3_ENDPOINT*, 
*S3_ACCESS_KEY*, and *S3_SECRET_KEY* to already be configured.

To deploy to ArgoCD, parse the yaml through `envsubst` and send to `kubectl create`. 
```
  export S3_ENDPOINT="https://minio.mydomain.internal:9000"
  export S3_ACCESS_KEY="myaccesskey"
  export S3_SECRET_KEY="mysecretkey"
  cat argo/spark-hs-argo.yaml | envsubst | k create -f -
```


## TLS 

Certificate should have the service names listed as the SAN
`DNS:spark-hs.spark.svc.cluster.local,DNS:*.spark.svc.cluster.local,DNS:spark-hs.spark,DNS:spark-hs.spark.svc`

Creating a Java Keystore involves first having a PKCS#12 formatted key pair, as 
the Java Keytool does not allow for importing private keys.

- Create a PKCS#12 container from a key pair.
  ```sh
  openssl pkcs12 -export -in sparkhs.crt -inkey sparkhs.key \
    -name sparkhs -out sparkhs.pfx
  ```

- Create the private Keystore
  ```sh
  keystore_passwd="mykeypass"
  keytool -importkeystore -deststorepass $keystore_passwd \
  -destkeystore keystore.jks -srckeystore sparkhs.pfx -srcstoretype PKCS12
  ```

- Create the Truststore
  ```sh
  cp $JAVA_HOME/jre/lib/security/cacerts ./truststore.jks
  ```

- Change the password of a truststore
  ```sh
  keytool -storepasswd -keystore truststore.jks
  ```

- Add the CA Certificate to the truststore
  ```sh
  keytool -importcert -alias rootca \
    -keystore truststore.jks -file ca.crt
  ```

- Set the keystore and truststore values when deploying the helm chart.
  ```sh
  keystore_data=$(cat keystore.jks | base64 -w0)
  truststore_data=$(cat truststore.jks | base64 -w0)
  keystore_passwd="mykeypass"
  truststore_passwd="mytrustpass"
  ```

  Note that the base64 versions of the keystore and truststore 
  exceed the shells maximum arguments length, so we pass those 
  in via the helm `--set-file` option.

  helm install [...] --set \
  keystoreBase64=$keystore_data,\
  keystorePassword=$keystore_passwd,\
  truststoreBase64=$truststore_data,\
  trustStorePassword=$truststore_passwd
  ```

  or a more complete version of the install command:
  ```
  helm install --create-namespace --set s3endpoint=${S3_ENDPOINT},s3accessKey=${S3_ACCESS_KEY},s3secretKey=${S3_SECRET_KEY},s3logDirectory=s3a://spark/spark-logs,service.type=LoadBalancer,secrets.keystorePassword=$keystore_passwd,secrets.truststorePassword=$truststore_passwd \
  --set-file secrets.keystoreBase64=keystore.b64 --set-file secrets.truststoreBase64=truststore.b64 \
  --namespace spark spark-history-server spark-hs-chart/spark-hs
  ```

### TLS/SSL Spark Configuration 

- `spark.ssl.<ns>` : Settings for a given sub-component

Where <ns> could be:
- `spark.ssl.ui`   : Spark application WebUI
- `spark.ssl.standalone`
- `spark.ssl.historyServer`

Spark configuration settings to be added to the ConfigMap
```
    spark.ssl.historyServer.enabled=true
    spark.ssl.historyServer.protocol=TLSv1.2
    spark.ssl.historyServer.port={{ .Values.service.externalPort }}
    spark.ssl.historyServer.keyStore=/mnt/secrets/keystore.jks
    spark.ssl.historyServer.keyStorePassword={{ .Values.secrets.keystorePassword }}
    spark.ssl.historyServer.keyStoreType=JKS
    spark.ssl.historyServer.trustStore=/mnt/secrets/truststore.jks
    spark.ssl.historyServer.trustStorePassword={{ .Values.secrets.truststorePassword }}
    spark.ssl.historyServer.trustStoreType=JKS
```

Creatng a Secret manually for a Keystore and Truststore
```
keystore="$1"
truststore="$2"

kubectl create secret generic spark-keystore \
  --namespace spark
  --from-file=keystore.jks=${keystore} \
  --from-file=truststore.jks=${truststore} \
  --dry-run=client -o yaml > secrets.yaml
```




