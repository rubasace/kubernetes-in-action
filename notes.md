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

