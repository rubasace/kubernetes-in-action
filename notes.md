# Kubernetes in Action

## Setup Tips
### Enable autocompletion (without kubectl alias)

```
sudo apt-get install bash-completion && \
echo 'source /usr/share/bash-completion/bash_completion' >> ~/.bashrc && \
echo 'source <(kubectl completion bash)' >> ~/.bashrc && \
source ~/.bashrc
```

### Enable autocompletion (with kubectl alias)
```
alias=k && \
sudo apt-get install bash-completion -y && \
echo 'source /usr/share/bash-completion/bash_completion' >> ~/.bashrc && \
echo "alias ${alias}=kubectl" >> ~/.bashrc && \
echo "source <(kubectl completion bash | sed s/kubectl/${alias}/g)" >> ~/.bashrc && \
source ~/.bashrc
```


### Switch clusters and namespaces (not from the book)
```
wget -P /usr/local/bin/ https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx \
                        https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens && \
chmod +x /usr/local/bin/kubens /usr/local/bin/kubectx
```

### Enable kubectx and kubens autocompletion
```
git clone https://github.com/ahmetb/kubectx.git ~/.kubectx && \
COMPDIR=$(pkg-config --variable=completionsdir bash-completion) && \
ln -sf ~/.kubectx/completion/kubens.bash $COMPDIR/kubens && \
ln -sf ~/.kubectx/completion/kubectx.bash $COMPDIR/kubectx && \
cat << FOE >> ~/.bashrc


#kubectx and kubens
export PATH=~/.kubectx:\$PATH
FOE && \
source ~/.bashrc
```

### Change text editor for kubectl edit

`export KUBE_EDITOR="/bin/nano"`

## Chapter 2: First Steps
### Create a ReplicationController (RC)

`kubectl run kubia --image=luksa/kubia --port=8080 --generator=run/v1` (deprecated?? use now `generator=run-pod/v1` instead??)

### Create a Service Exposing RC

`kubectl expose rc kubia --type=LoadBalancer --name kubia-http`

`kubectl get svc` (check external ip)

hit external ip using curl: `curl ${externalip}:8080`

### Scale RC

`kubectl scale rc kubia --replicas=3`

### Get Info from Resources

`kubectl get pods -o wide` for more info like node and ip

`kubectl get pods ${podname} -o yaml` for info in yaml (can be json too)

`kubectl describe pod ${podname}` for details of specific resource (pod in this case)

`kubectl describe node` for all information of every resource (node in this case)

## Chapter 3: Pods

### Logs

`kubectl logs ${podname}`

`kubectl logs ${logname} -c ${containername}` when multiple pods

### Port Forwarding

`kubectl port-forward kubia-manual 8888:8080` to access pod 8080 from localhost:8888

### Explain resources
`kubectl explain pods`

`kubectl explain pod.spec`


### Label Selector (pods, nodes...)

`kubectl get pod --show-labels` (show all labels)

`kubectl get node -l gpu` (all with label `env` and any value on it)

`kubectl get pod -l ‘!env’` (not label env)

`kubectl get node -l ‘gpu in (high, medium)’` (label with any of those values)

`kubectl get pod -l ‘env notin (debug, prod)’` (label without any of those values)

 ### Add Label to Resources

`kubectl label pod env=prod (add label)`

`kubectl label pod env=prod (add label)`

### Add annotations to Resources

`kubectl annotate pod kubia-manual mycompany.com/description="Manual Pod for testing purposes"` (use `--overwrite` if already exists)

`kubectl annotate pod kubia-manual mycompany.com/description-` (`-` at the end of the annotation name) to remove an existing annotation

Annotations can be retrieved via `kubectl get -o yaml` or via `kubectl describe`

### Delete Resources
`kubectl delete po kubia-gpu`

`kubectl delete po kubia-gpu kubia-manual`

`kubectl delete po -l creation_method=manual` 

`kubectl delete po --all` all pods in active namespace

`kubectl delete ns custom-namespace` 

`kubectl delete all --all` almost all resources in active namespace (some like secrets don't get deleted)

### Namespaces

`kubectl get ns`

`get po --namespace kube-system` / `get po -n kube-system`

`kubectl create namespace custom-namespace` (or applying `custom-namespace.yaml` from examples)

`kubectl create -f kubia-manual.yaml -n custom-namespace` to create in custom namespace (or add to metadata in yaml, like `kubia-manual-custom-namespace.yaml`)

### Final Notes
Every time a node is added it's a good practice to attach labels to it to categorize it. See `nodeSelectors` from `kubia-cpu.yaml`

## Chapter 4: Replication and other Controllers

### Liveness Probe Basics

Used to check from outside the application that this is still alive. Kubernetes can use three mechanisms:
* HTTP GET, checking status code (alive if 2xx or 3xx)
* TCP socket, checking if a connection can be established
* Exec probe, executing a command inside the container and checking it's return code (alive only if 0)

If a container is restarted, logs from before the restart can be retrieved via `kubectl logs kubia-liveness --previous`. 

To get the reason why a pod had to be restarted `kubectl describe pod kubia-liveness` can be used

**Important**!!: configure `initialDelaySeconds` to give enough time to the application to startup.
 
For detailed configuration options, execute `kubectl explain pod.spec.containers.livenessProbe`

### Liveness Probe Tips

Don't depend on external services.

Keep it light

Don't implement retry on the endpoint (configure it on the livenesProbe instead)

### Extra Notes about Pods vs RCs
Pods are handled by Kubelet, who lives in the same node. If an entire node crashes, Kubernetes won't reschedule it's pods in a different node. ReplicationController
 and similar mechanisms solve this issue.
 
### ReplicationController anatomy
RCs consist of three essential parts:
* label selector, to check current number
* replica count, specifying desired number
* pod template, used for creating new pods

Important to understand that changes on RCs, other than `replica count`, don't affect existing pods. Pods that fall out of the filter aren't managed anymore and `pod template
` is only used for creating new ones.

Tip: if the selector isn't defined, Kubernetes will extract it from the pod template (keeping yaml smaller)
 
Pods can be moved to another RC or even remove from all by changing labels. `metadata.ownerReferences` refers to the RC that created it.
 

### Edit resources

`kubectl edit rc kubia`

`kubectl edit po kubia-9zn4w`

### Deleting RC

By default RCs delete managed pods. It can be avoided with the flag `--cascade=false`.

### ReplicaSet 

Should be used instead of RCs. They offer the same but with more options to select (multiple values for same key, key presence regardless of the value, etc)


### DaemonSet

Run one single pod per node. It can use `nodeSelector` to filter which nodes are targeted.


### Job
Executes only once and finishes (unlike RC or RS). If the node fails they will be rescheduled. If the task fails it depends on the `restartPolicy` (`OnFailure` or `Never
`, always isn't allowed as this is what prevents the Job to be restarted).

`completions` controlls the number of runs, `parallelism` controlls the number of executions in parallel. 

`activeDeadlineSeconds` controls maximum time for the pod before being killed. `backoffLimit` controls the how many times the job can be retried.

`kubectl scale job multi-completion-batch-job --replicas=3` to change parallelism


### CronJob
 
 CronJob just creates Jobs at **approximately** the scheduled time. The max deadline can be controlled via `startingDeadlineSeconds`, if exceeded the Job will be marked as failed.
 
 **Important:** In some cases it's possible that cronjobs run twice or not at all. Therefore Jobs scheduled via CronJob should be idempotent and should perform any work that
  should have been performed by previous runs in case those missed.
  
  
 ## Chapter 5: Services
 
 Expose a single accesspoint (ip/DNS) for all pods backing up the service. Very important as pods are ephemeral.
 
 `kubectl expose rc kubia --type=LoadBalancer --name kubia-http` to create via command or via YAML (`kubia-svc.yaml`)

### Execute command inside pods
`kubectl exec kubia-7b4lc -- curl -s http://10.16.12.61` The double dash(`--`) signals the end of the command options, so the rest is executed inside the pod. 

`kubectl exec kubia-7b4lc -it sh` Parameters `-it` can be passed if STDIN needs to be passed to the container (`-i`) and we want to interact with the terminal (`-t`). 

### Session Affinity

`sessionAffinity: ClientIP` can be used to redirect the client always to the same pod. Only `ClientIp` and `None` are valid values.

### Multiple Ports

A single service can expose multiple podd, but each port has to have a name

### Using Named Ports

Services can refer in `targetPort` the name of the port from the Pod definition, instead of hardcoded numbers. `kubia-svc-namedports.yaml` shows this (make sure to delete the
 old pods after applying, so the new ones have the named ports). This is a good practice so pod port numbers can be changed later, without needing to change the service at all
 . Even different versions of the pod can be used with different port numbers
 
 ### Discovering services
 
 Pods created after service can see all services ips from envars: `exec kubia-rbx69 env`
 
 All pods are connected to `kube-dns` and can resolve ip via fully qualified domain name (FQDN).  (`http://kubia.default.svc.cluster.local:443` will call the `kubia` service
  IP on port 443).  The namespace and `svc.cluster.local` can be omitted from the same namespace and cluster (check `/etc/resolv.conf` inside the container for more info)
  
 The usage of this internal DNS can be controlled via `dnsPolicy` on each Pod spec.
 
 ### Ping doesn't work
 
 Services are just virtual IPs that only work in combination with the service ports. So pinging to test if a service is working won't work, though curl works.

### Connecting to services outside the cluster

 Services can be created without a selector. If so, Kubernetes won't create the Endpoint resource associated to it. We can create it manually specifying the addresses and ports
  (check `external-svc.yaml`). It's important that both **Service and Endpoints have the same name**.
  
 An alternative is creating a service with type `ExternalName`, that exposes an external service via it's FQDN (check `externalname-svc.yaml`).
 
 ExternalName services don't get a cluster IP as they are just CNAME DNS records. 
 
 
 ### Exposing services to external clients

Can be done in three ways:
* Service with type `NodePort`: a port open on each cluster node
* Service with type `LoadBalancer`: dedicated loadbalancer with an IP provided by the cloud infrastructure (won't work on-premise)
* Creating an Ingress resource: It allows to expose multiple services on a single IP address. Also operates at L7 (HTTP) so can offer more features than L4.


### Filter fields with -o jsonpath
`kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}'`  More documentation in https://kubernetes.io/docs/reference/kubectl/jsonpath/

 
 ### NodePort
 
 NodePort opens a specific port on all nodes of the cluster. By adding a firewall rule (on GCP), we can access the service via any of the nodes IP and the specified port.
 
 ### LoadBalancer
 
 It's important to understand that LoadBalancers are just NodePort services with and additional load-balancer infrastructure. Therefore, by describing the LoadBalancer we can see
  that a random NodePort has been assigned. If we open that port on the firewall, we can access the service via any NodeIP, in the same way as the NodePort resource. This is
   definitely not needed, as the cloud provider will assign an external IP to the loadBalancer, abstracting clients from specific node IPs (nodes can fail, we might want to
    balance traffic across multiple nodes, etc)
  
### Session Affinity on web browsers and LoadBalancer

Even when session affinity is set to `None`, browsers use `keep-alive` connection and send all requests through the same connection. This means that after the connection is
 first opened, a random pod is selected. From then on, until the connection gets closed, all network communication is done with the same pod.

### Peculiarities of external connections

Connections through a NodePort (including via a LoadBalancer) choose randomly a pod. This might cause the traffic to be redirected to another's node pod, adding an extra network
 jump. This can be avoided setting `externalTrafficPolicy: Local` on the service spec. Connection will hang if there's no pod on the node. This also affects load balancing
  (traffic evenly distributed across nodes, but not across pods)
  
### Ingress

LoadBalancers require one public IP per service.

Ingress requires one ingress controller (and only one public IP that can expose multiple services)

On cloud providers, ingress controllers need to point to a NodePort (required by cloud providers, not Kubernetes)

### Ingress + cloud providers
Ingress requires to point to a NodePort on cloud providers

### ReadinessProbe

Similar to LivenessProbe, it indicates Kubernetes when a por is ready to receive traffic (so services don't start sending traffic to pods that are still starting up)

Kubernetes can use three mechanisms:
* HTTP GET, checking status code (alive if 2xx or 3xx)
* TCP socket, checking if a connection can be established
* Exec probe, executing a command inside the container and checking it's return code (alive only if 0)

It acts like another label for the service (pods can move from non-ready to ready and vice-versa). But it doesn't affect the pod numbers!! A ReplicaSet for 3 instances will
 always have 3 instances matching the selector, it doesn't matter if they are ready or not.
 
 **Always define a readinessProbe** 
 
 ### Add/Remove pods from service manually
 It's recommendable to add a label `enabled=true` or `serving=true` or something along those lines, both to the pods (RC/RS template) and to the service selector. That way we
  can modify the label to pull off a pod from a service (or put it back in). Priceless for some situations where we need to debug what's going on in production.
  
 ### Exposing every pods IP
  
  We can expose every pods IP under a single service, making it headless (`clusterIP: None`). Have a look at `kubia-svc-headless.yaml`. By default it will only show ready pods
  , this can be changed via `publishNotReadyAddresses` field in the service spec.
  
### TroubleShooting services
1. Make sure to connect from inside the cluster
2. Don't even try ping (virtual IP, won't work)
3. Check readiness probe of pods
4. Check if a pod is part of a service by checking the Endpoint with `kubectl get endpoints` (`ENDPOINTS` field should show all pod IPs) 
5. If FQDN doesn't work try to connect using its cluster IP instead
6. Check you are connecting through exposed port, not target port
7. Make sure the app is not only binding to localhost

## Chapter 6: Volumes
Volumes are pod components, like containers. 

They share its lifeycle (persiste accross restarts, but get deleted along with the pod). 

They are available to all containers in a pod, but need to be mounted at a container level, individually, to its filesystem.

### Several volume types
* emptyDir: empty directory for transient data
* hostPath: to mount directories from the node's filesystem
* gitRepo: directory with git repo content
* nfs
* ConfigMap, Secret
* Many others...

### EmptyDir
Starts up empty and data is lost when pod gets deleted.

Useful for sharing data between containers. 

Also useful as temporary storage for the container (might be only option if container fs isn't writable).

### GitRepo
Checks out repository at creation. Won't sync.

If you need to sync you'll need a sidecar container doing the job (check `fortune-pod-gitsync.yaml`)

### HostPath
Mounts a file or directory from the node fs to the containers one. 

Properly persistent (will persiste data even after the pod gets deleted)

Should not be used for persistence on multi-node, data stored in a particula node. Therefore, if pod gets scheduled to a different node, it won't have access to the same data
. NFS, vendor specific like GCE volumes, etc are way better options.

Used widely by GKE (and probably others) to read node information (not to store data), as for example fluentd (accessing `/var/log`, `/var/lib/docker/containers` and `/var/run/google-fluentd`).

### GCE persistent disk

`gcloud compute disks create --size=1GiB --zone=europe-west2-c mongodb` (ignore warning on size)

### PersistentVolumes and PersistentVolumeClaims

Defining volumes inside a pod goes against Kubernetes (knowing the NFS server address, setting up the persistent disk, etc)

Two well separated resources:

* PersistentVolume: administrators setup the storage and register it by creating PersistentVolume (including size and accessModes)
* PersistentVolumeClaim: defines storage requirements and access mode. The PersistentVolumeClaim gets then added as a volume to the pod.

PersistentVolumeClaims are separate resources from Pods, so the volume claim can stay available even if the pod is deleted.

### Dynamic provisioning of PersistentVolumes
Instead of provisioning PersistentVolumes directly, we can define StorageClass that will use provisioners to dynamically provide PersistentVolumes.

Done through `spec.provisioner` that will receive `parameters`.

PersistentVolumeClaims can refer to the `storageClass` by name

StorageClass allows to provide different kinds of storage by name, without exposing the internals of what is being provided

When we define `storageClassName: ""` we are indicating the PersistentVolumeClaim that we want to use a pre-provisioned PV, instead of a dynamically provisioned one

The best way of attaching storage to a pod is using a PersistentVolumeClaim and a Pod mounting it. PVC will get a StorageClass by default, but can be customized). That way the
 dynamic volume provisioner will take care of everything else.
 
 
## Chapter 7: ConfigMaps and Secrets

We can configure apps in three ways:
* Passing command-line argumments
* Setting envars
* Mounting files

### ENTRYPOINT and CMD
* ENTRYPOINT defines the executable invoked when container is started
* CMD specifies arguments passed to ENTRYPOINT (it can be used also to specify the command instead of the ENTRYPOINT, though less correct)

### shell and exec forms

* shell (`node app.js`) 
* exec  (`["node", "app.js"]`)

exec ENTRYPOINT runs the process directly (not inside a shell), while shell runs it as a child process of the shell. As the shell process isn't necessary, exec form is better
 for ENTRYPOINT.
 
 
### Container ENTRYPOINT and CMD

`container.command` = ENTRYPOINT

`container.args` = CMD

### CongfigMaps
Separate configuration from pod (different configurations on different environments, with same pod definition)

from literal: `kubectl create configmap fortune-config --from-literal=sleep-interval=25`

from multiple literals: `kubectl create configmap fortune-config --from-literal=sleep-interval=25 --from-literal=another=hello`

from content of a file: `kubectl create configmap config-from-file --from-file=config-file.conf`

by default key of the data entry will be name of the file, can be changed providing the name of the key (`newkey` in the example): `kubectl create configmap config-from-file --from-file=newkey=config-file.conf`

from directory: `kubectl create configmap config-from-file --from-file=directoryName` (will create one entry per file in the directory)

**All options can be combined in any way**

Can be passed into container in three ways:
* envar
* argument (reading envar)
* volume mount

If Configmap doesn't exist, pod won't startup, unless ConfigMap reference is marked as optional (`configMapKeyRef.optional: true`)


#### ConfigMap as envars
reference with `env.valueFrom` + `key` for single values

reference with `envFrom` + `configMapRef` for all envars (setting `PREFIX` if you want specific prefix)

**Only valid DNS names** will be accepted as envars. `-` isn't a valid character, so envars containing it will be ignored.

#### ConfigMap as args
Same as envars, and then refering envar on the `args`

**IMPORTANT:** variables are referred with parentesis (`$(ENVAR_NAME)`), not with curly brackets (`${ENVAR_NAME}`).

#### ConfigMap as volume
More useful when we want to provide lots of parameters, configuration files, etc.

Mount using `configMap` on the volume definition.

Can specify which items to mount using `items`

**IMPORTANT:** mounting volumes hide existing files (Linux mounting on non-empty directory)

####ConfigMap as files (not overriding directory)

We can use `subPath` on the volumeMount to mount a file inside an existing directory (see `fortune-pod-configmap-volume-subpath.yaml`)

#### Changing default permission

We can use `defaultMode` on the volume definition to change default permission of files (see `fortune-pod-configmap-volume-defaultmode.yaml`)


#### Updating ConfigMap

Updating the ConfigMap updates the mounted volume to reflect the changes (up to the container to reload it or not)

It still takes a lot of time to refresh (v1.14.10)

Files are updated atomically!! files are symlinks pointing to a `..data` folder. Data folder is also a symlink pointing to another dir. When the mount changes, a new
 dir is
 created and then `..data` points to it, changing all files at the same time.
 
 ```bash
# kubectl exec -it fortune-configmap-volume -c web-server -- ls -lA /etc/nginx/conf.d
 drwxr-xr-x    2 root     root          4096 Feb 29 12:42 ..2020_02_29_12_42_06.288600198
 lrwxrwxrwx    1 root     root            31 Feb 29 12:42 ..data -> ..2020_02_29_12_42_06.288600198
 lrwxrwxrwx    1 root     root            27 Feb 29 12:35 my-nginx-config.conf -> ..data/my-nginx-config.conf
 lrwxrwxrwx    1 root     root            21 Feb 29 12:35 sleep-interval -> ..data/sleep-interval

```

**IMPORTANT:** files mounted individually don't get updated when ConfigMap changes, only directories (checked with v1.14.10)

Updating a configMap can cause different pods to behave differently for a period of time, as new created ones will have the latest values while previous instances will take some
 time to update.
 
If the app doesn't reload configuration automatically, then it's a bad idea to modify and existing ConfigMap

### Secrets


Similar to ConfigMap but Kubernetes keeps them safe: always stored in memory, only passed to nodes that need them and stored encrypted.

Can be used as ConfigMap:
* envars (not recommended, as many apps expose envars somehow) using `env.valueFrom.secreatKeyRef`
* as files in volumes (uses tmpfs, so never get written to disk) using `volume.secret.secretName`

Should be used when storing sensitive data

Data is encoded, not encrypted! (`get -o yaml` or `describe`)

Can contain text or binary, but up to 1MB

Can use `stringData` to add non-binary data (write-only, it will then appear under `data`)

### Docker Registry Secret

Used to authenticate against private docker registries when pulling images. 
Can be used from `pod.spec.imagePullSecrets` or as part of the ServiceAccount, so doesn't need to go into each pod definition.


## Chapter 8: accessing pod metadata and other resources

### Downward API

Kubernetes can pass some information down to containers:
* Pod name
* Pod ip address
* namespace
* node name
* service account name
* CPU/memory request
* CPU/memory limit
* pod labels
* pod annotations

Can be passed as volumes or as envars (labels and annotations cannot be passed as envars, cause they can change and there aren't mechanisms for updating envars).

When passed as volumes, for `resourceFieldRef`,  the container needs to be specified (even if there's only one)

Accessible via `fieldRef` and `resourceFieldRef`. Resources can specify the divisor (1 or 1m, for CPU or 1, 1k, 1Ki, 1M, 1Mi... for memory)

### API Server

can be called locally executing `kubectl proxy` and connecting through it (takes care of validating certificate and authentication)

can call from inside the pod using injected secrets (token and certificate):

```bash
curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $TOKEN" https://kubernetes
```
If RBAC (Role Based Access Control) is enabled, it might give error in authentication 

Three files are injected in `/var/run/secrets/kubernetes.io/serviceaccount/`, all required for communication:
* app needs to verify API server certificate (using `ca.crt` file )
* app authenticates sending `Authorization` header  (using `token` file)
* request resources for a namespace, can know on which one it using `namespace` file

### API Server through Ambassador

Instead of pod dealing with all https and validation, can connect using plain HTTP through a container that takes care of everything (ambassador pattern) (check `curl-with
-ambassador.yaml`)

Then it can be called from inside the pod using localhost, as all containers in the same Pod share the same network interface: curl localhost:8001


### API Clients

If we need to do complex stuff with Kubernetes API we can use specific libraries such as Golan client or Python client.

There are plenty of other non-oficial libraries (Java, Node, PHP, Ruby...)

## Chapter 9: Deployments

Three options:
* Delete old pods and replace with new ones (adds downtime)
* Add new pods, switch service to new version and delete old pods (uses more resources due to duplicated pods)
* Rolling update: progressively sin up new version and delete old one


### ImagePullPolicies
For tag `latest` the default policy is  `Always` which means that it will always try to pull it again

For any other, the default policy is `IfNotPresent`. 

That means that, if we override in docker any tag that isn't `latest`, the new image won't be downloaded if it already existed.


### Rolling Update using kubectl rolling-update

```
kubectl rolling-update kubia-v1 kubia-v2 --image=luksa/kubia:v2
```
Copies RC kubia-v1 and changes image to the new one specified.

Adds extra `deployment` label to template and selector of new RC

Also adds different `deployment` label to selector of old RC and old pods

Kubernetes handles both RCs desired numbers to slowly scale up new one while scaling down the old one

Service doesn't change so it matches both old and new pods, so traffic gets progressively switched to more pods of the new version till finnally that's the only one serving traffic

It's deprecated!

Main problems:
* modifies your objects (labels on pods and selectors on RCs)
* it operates on the client (network problems can cause serious issues)
* it's imperative (we ask about the action, we don't define the state we would like to achieve)


### Deployment

A Deployment is higher level than RS or RC.

Operates declaratively, and creates a RS underneath (RS manages pods, not Deployment).

It takes care of the process `kubectl rolling-update` takes care of (Kubernetes control plane does, but that's the idea)

**IMPORTANT** Use `--record` when applying deployments, to record it in the revision history

Deployment creates multiple RS (one per version)

Unlike with kubectl, the old RS is still there (with 0 derired)

### Rollback deployment

deployments can be rollbacked using `kubectl rollout undo deployment kubia`. Can it be done even during the rollout process

we can return to an old revision using `kubectl rollout undo deployment kubia --to-revision=1` (it can rescale old RCs that are not at 0)


### Configure rollingUpdate

`deployment.spec.strategy.rollingUpdate.maxSurge`: how many pods can be above the desired replica count
`deployment.spec.strategy.rollingUpdate.maxUnavailable`: how many pods can be unavailable in relation to the desired replica count (still not ready)

desired 3, maxSurge 3 and maxUnavailable 1 means that maximum 4 pods can exist at any moment, and at least 2 need to be available (max 1 of the 3 desired plus the 1 that surges)

They accept absolute values or percentages (relation to desired replicas)

### Get rollout history

```bash
kubectl rollout history deployment kubia
```

### Pause rollout process

```bash
kubectl rollout pause deployment kubia
```

Useful for performing canary releases (very basic)

It also prevents further updates to the deployment until it's resumed

### Resume rollout process

```bash
kubectl rollout resume deployment kubia
```

### MinReadySeconds to block rollouts of bad versions

By setting `minReadySeconds` we tell the deployment that the pod needs to be ready for that amount of time, preventing it to continue the process till then. 

With a good readinessProbe and a proper waiting time we can make Kubernetes get stuck on the deployment of versions that otherwise might affect the client.

This rollout can then be aborted using `rollout undo`. Future versions of Deployment have `progressDeadlineSeconds` that will abort automatically.

### Modify Resources

There are multiple ways:

* `kubectl edit`: open manifest in editor and updates on exit
* `kubectl patch`: modifies properties of object (specified with `-p`)
* `kubectl apply`: modifies object from full json/yaml (creates if doesn't exist)
* `kubectl replace`: like apply but fails if the object doesn't exist
* `kubectl set image`: changes container image in pod, RC, Deployment, DS, Job or RS




