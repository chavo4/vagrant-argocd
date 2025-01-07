# Vagrant<->Argocd POC
## Prerequisites
[Vagrant](https://www.vagrantup.com/)</br>
[VirtualBox](https://www.virtualbox.org/)</br>
Basic [Kubernetes](https://kubernetes.io/docs/setup/) knowledge</br>
Basic [ArgoCD](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/) knowledge 

### Lets start
##### clone the repo
```
git clone https://github.com/chavo1/vagrant-argocd.git
cd vagrant-argocd
vagrant up
```

### === Access Information ===
#### Development Environment:
URL: http://192.168.56.11:30001
#### Production Environment:
URL: http://192.168.56.11:30002

#### ArgoCD Dashboard:
URL: https://192.168.56.11:8080</br>
Username: admin</br>
Password: just copy or open "/vagrant/argocd-password.txt"

#### Switch between v1 and v2 of tetris, don't forget "Sync" buton under the ArgoCD->Applications 
```
base/deployment.yaml
```
```
    spec:
      containers:
      - name: tetris
        image: chavo/tetris:v2 # try by changing to -> chavo/tetris:v1
```

[![ArgoCD UI](./screenshots/argcd.png)](https://argo-cd.readthedocs.io/en/stable/getting_started/)
[![ArgoCD UI](./screenshots/argocdapps.png)](https://argo-cd.readthedocs.io/en/stable/getting_started/)
[![Tetris UI](./screenshots/tetris.png)](https://hub.docker.com/r/chavo/tetris)
