# -*- mode: ruby -*-
# vi: set ft=ruby :

KUBE_VERSION="1.32"
MASTER_COUNT=1

Vagrant.configure("2") do |config|
  config.vm.box = "chavo1/rocky9.3"
  config.vm.provision "shell", inline: <<-SHELL
  echo "192.168.56.11       master-1" >> /etc/hosts
  SHELL

1.upto(MASTER_COUNT)do |i|
    config.vm.define "master#{i}" do |master|
      master.vm.hostname  = "master-#{i}"
      master.vm.provision "shell", path: "./scripts/k8s-centos.sh", env: {"KUBE_VERSION" => KUBE_VERSION}
      master.vm.provision "shell", path: "./scripts/argocd-install.sh"
      master.vm.provision "shell", path: "./scripts/application.sh"
      master.vm.network "private_network", ip: "192.168.56.#{i+10}"
      master.vm.provider "virtualbox" do |pmv|
        pmv.memory = 8192
        pmv.cpus = 4
      end
    end
  end
end