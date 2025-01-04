# Vagrant<->Argocd POC
## Prerequisites
[Vagrant](https://www.vagrantup.com/)</br>
[Kubernetes](https://kubernetes.io/docs/setup/)</br>
[ArgoCD](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)

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

#### Switch between v1 and v2 of the tetris app
```
base/deployment.yaml
```
[![ArgoCD UI](./screenshots/argcd.png)](https://argo-cd.readthedocs.io/en/stable/getting_started/)
[![ArgoCD UI](./screenshots/argocdapps.png)](https://argo-cd.readthedocs.io/en/stable/getting_started/)
[![Tetris UI](./screenshots/tetris.png)](https://hub.docker.com/r/chavo/tetris)
