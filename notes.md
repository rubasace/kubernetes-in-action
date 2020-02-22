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


