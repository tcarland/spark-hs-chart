Spark 3 History Server Helm Chart
===============================

A helm chart for deploying the Spark History Server to Kubernetes
using S3 Object Storage for the Spark Event Logs. Many of the existing
charts do not account for the S3 requirements. This chart was created
specifically for Spark 3 using S3 for the history logs.

<br>

## Configuration

The chart takes a few primary config parameters; other options
can be customized by adjusting the values file.

|     Option     | Description |
| -------------- | ----------- |
| s3endpoint     | The S3 Endpoint URL   `https://minio.minio.svc` |
| s3logDirectory | The path to S3 bucket `s3a://spark/spark-logs` |
| s3accessKey    | The S3 Access Key |
| s3secretKey    | The S3 Secret Key |

- *s3endpoint* in the format of `https://minio.minio.svc.cluster.local:443`
- *s3logDirectory* defines the bucket path, which defaults to `s3a://spark/spark-logs`
- Additional values for TLS is described in this [section](#configuring-tls)

<br>

## Install the Helm Chart

Config parameters can be added to a custom version of *values.yaml*
and passed to helm via `-f myvalues.yaml` or via the `--set` directive.

A service account for spark is needed and should be created ahead of
time or set *serviceAccount.create* as *true* in the `values.yaml`
file (the default is already `true`). This results in the following
being applied:
```sh
kubectl create namespace spark
kubectl create serviceaccount spark --namespace spark

kubectl create clusterrolebinding spark-rolebinding \
--clusterrole=edit \
--serviceaccount=spark:spark \
--namespace=spark
```

Install by a values file
```sh
helm install -f <myvalues.yaml> \
--namespace <ns> \
<release-name> <path_to_chart>
```

Alternative install via helm command-line.
```sh
helm upgrade --install spark-hs . \
--create-namespace --namespace spark
--set s3endpoint=${S3_ENDPOINT} \
--set s3accessKey=${S3_ACCESS_KEY} \
--set s3secretKey=${S3_SECRET_KEY} \
--set s3logDirectory=s3a://spark/spark-logs \
--set service.type=LoadBalancer \
--set image.repository=gcr.io/myproject/spark
```

The github also acts as our chart repository by using gh_pages
served from *github.io*.
```sh
helm repo add spark-hs-chart https://tcarland.github.io/spark-hs-chart/
helm install spark-history-server spark-hs-chart/spark-hs \
--create-namespace --namespace spark --set option=foo
```

## Uninstall Chart

Simply use helm to remove the deployment
```sh
helm uninstall --namespace spark spark-hs
```

## Accessing the UI

By default the Service is using *ClusterIP*. Typically, we add an
ingress gateway and use *LoadBalancer*.

A quick validation would be to port-forward the history server port.
```bash
# get pod name and service port
relname="spark-hs"
ns="spark"

POD_NAME=$(kubectl get pods -n $ns | grep $relname | awk '{ print $1 }')
HS_PORT=$(kubectl get service $relname -n $ns -o=json | jq .spec.ports[0].port)

# port forward
kubectl port-forward $POD_NAME $HS_PORT --namespace $ns &
```

If the service type was set to NodePort, acquire the Application URL.
```bash
export NODE_PORT=$(kubectl get --namespace spark -o jsonpath="{.spec.ports[0].nodePort}" services spark-hs)
export NODE_IP=$(kubectl get nodes --namespace spark -o jsonpath="{.items[0].status.addresses[0].address}")
echo https://$NODE_IP:$NODE_PORT
```

## Building a Spark Image
￼
The Apache Spark distribution provides a *Dockerfile* and an image build
tool for generating container images. Typically a binary package
dowloaded from spark.apache.org will work fine.  The spark images
referenced by this repository use a Spark3 package with Hadoop3 libs
included, but this is generally chosen to match ones environment.

Custom JARs can be added to $SPARK_HOME/jars prior to building the
image, but the jars should be tested to ensure there are no dependency
collisions that would require shading resources.

The dockerfile used by the image-tool is located at
*$SPARK_HOME/kubernetes/dockerfiles/spark/Dockerfile*

The typical image build process:
```bash
export SPARK_HOME=/opt/spark
cd $SPARK_HOME
./bin/docker-image-tool.sh -r quay.io/myacct -t 3.5.6-myrelease build
[...]
Successfully build f07cd00df877
Successfully tagged quay.io/myacct/spark:3.5.6-myrelease
```

### Scala Versions

In the context of the history server, the underlying Scala version
does not really matter, Spark 3 supports either 2.12 or 2.13.
It can be useful to tag the image accordingly as this version is
key when it comes to other 3rd party Scala dependencies such as Iceberg
or Hudi. Unfortunately, some 3rd party projects have not fully adopted
Scala 2.13 yet (eg. Hudi, Flink). The default images provided here are
built using 2.13, with included Iceberg and Delta dependencies.

<br>

---

## Configuring TLS

If exposing the HistoryService via TLS, certificates should have the
*CommonName* as the exposed FQDN with the Kubernetes internal service
names listed as the *SubjectAlternateName* (SAN) such as the following
example.
```
DNS:spark-hs.spark.svc.cluster.local,DNS:*.spark.svc.cluster.local,DNS:spark-hs.spark,DNS:spark-hs.spark.svc
```

Creating a Java Keystore involves first having a PKCS#12 formatted
key-pair, as the Java Keytool does not allow for importing private keys.

- Create a PKCS#12 container from a key pair.
  ```sh
  openssl pkcs12 -export -in spark-hs.crt -inkey spark-hs.key \
  -name spark-hs -out spark-hs.pfx
  ```

- Create the private Keystore
  ```sh
  keystore_passwd="mykeypass"
  keytool -importkeystore -deststorepass $keystore_passwd \
  -destkeystore spark-hs.jks -srckeystore spark-hs.pfx -srcstoretype PKCS12
  ```

- Create and/or add the CA Certificate to the truststore. This will prompt
  for a truststore password.
  ```sh
  keytool -importcert -alias rootca -keystore truststore.jks -file ca.crt
  ```

- Change the password of a truststore. NOTE: Truststores do not need to 
  be as 'secret' as keystores thus it is often easier to use the default
  password used with all Java distributions.
  ```sh
  keytool -storepasswd -keystore truststore.jks
  ```

- Set the keystore and truststore values when deploying the helm chart.
  Note the keystore and truststore files must be relevant to the helm 
  chart root for helm `.Files.Get` to function properly.
  ```bash
  helm install [...] --set \
  secrets.keystoreFile=spark-hs.jks,\
  secrets.keystorePassword=$keystore_passwd,\
  secrets.truststoreFile=truststore.jks,\
  secrets.trustStorePassword=$truststore_passwd
  ```

- A complete version of the install command:
  ```bash
  helm upgrade --install spark-history-server spark-hs-chart/spark-hs \
  --namespace spark --create-namespace \
  --set s3.endpoint=${S3_ENDPOINT} \
  --set s3.region=${S3_REGION} \
  --set s3.accessKey=${S3_ACCESS_KEY} \
  --set s3.secretKey=${S3_SECRET_KEY} \
  --set s3.logDirectory=s3a://spark/spark-logs \
  --set service.type=LoadBalancer \
  --set secrets.keystorePassword=$keystore_passwd \
  --set secrets.truststorePassword=$truststore_passwd \
  --set-file secrets.keystoreFile=spark-hs.jks \
  --set-file secrets.truststoreFile=truststore.jks
  ```

<br>

---

## Using ArgoCD to deploy a helm chart

An Argo *Application* yaml as in *argo/spark-hs-argo.yaml* which defines
the required chart values. The argo app sets secrets through environment
vars which shold be set prior to deploying. The yaml provided expects
*S3_ENDPOINT*, *S3_ACCESS_KEY*, and *S3_SECRET_KEY* to already be configured.

To deploy to ArgoCD, parse the yaml through `envsubst` and send to `kubectl create`.
```bash
export S3_ENDPOINT="https://minio.mydomain.internal:443"
export S3_ACCESS_KEY="myaccesskey"
export S3_SECRET_KEY="mysecretkey"
cat argo/spark-hs-argo.yaml | envsubst | k create -f -
```

<br>

---

<br>

## TLS/SSL Spark Configuration Notes

Details on Spark TLS Configuration options.

- `spark.ssl.<option>` : Sets parameters for all components

- `spark.ssl.<ns>` : Settings for a given sub-component

Where `<ns>` is the subcomponent:
- `spark.ssl.ui`   : Spark application WebUI
- `spark.ssl.standalone`
- `spark.ssl.historyServer`

Spark configuration settings to be added to the ConfigMap
```ini
spark.ssl.historyServer.enabled=true
spark.ssl.historyServer.protocol=TLSv1.2
spark.ssl.historyServer.port=18080
spark.ssl.historyServer.keyStore=/mnt/secrets/keystore.jks
spark.ssl.historyServer.keyStorePassword={{ .Values.secrets.keystorePassword }}
spark.ssl.historyServer.keyStoreType=JKS
spark.ssl.historyServer.trustStore=/mnt/secrets/truststore.jks
spark.ssl.historyServer.trustStorePassword={{ .Values.secrets.truststorePassword }}
spark.ssl.historyServer.trustStoreType=JKS
```

Creating a Secret manually for a Keystore and Truststore. Note that use
of `--from-file` already base64 encodes the provided files.
```sh
keystore="$1"
truststore="$2"

kubectl create secret generic spark-keystore \
--namespace spark \
--from-file=keystore.jks=keystore.jks \
--from-file=truststore.jks=truststore.jks \
--dry-run=client -o yaml > secrets.yaml
```
