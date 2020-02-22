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
  
  
 
 
 



