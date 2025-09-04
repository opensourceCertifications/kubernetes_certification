# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Base VM config
  config.vm.box = "ubuntu/focal64"
  config.vm.box_check_update = false

  # IP assignments
  master_ip   = "192.168.57.10"
  frontend_ip = "192.168.57.11"
  backend_ip  = "192.168.57.12"
  database_ip = "192.168.57.13"

  # VM settings template
  def setup_node(node, hostname, ip, master_ip)
    node.vm.hostname = hostname
    node.vm.network "private_network", ip: ip
    node.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus = 2
    end
    # Use unique SSH ports to avoid conflicts
    ssh_port = case hostname
      when "k8s-master"   then 2210
      when "k8s-frontend" then 2220
      when "k8s-backend"  then 2230
      when "k8s-database" then 2240
    end
    node.vm.network "forwarded_port", guest: 22, host: ssh_port, id: "ssh", auto_correct: true

    # Export IP to /etc/environment
    node.vm.provision "shell", inline: <<-SHELL
      echo "NODE_IP=#{ip}" | tee -a /etc/environment
      echo "MASTER_IP=#{master_ip}" | tee -a /etc/environment
    SHELL

    # Run common setup script
    node.vm.provision "shell", path: "./scripts/setup.sh"
  end

  # Master Node
  config.vm.define "k8s-master" do |master|
    setup_node(master, "k8s-master", master_ip, master_ip)
    master.vm.provision "shell", path: "./scripts/setup-master.sh"
    
    # After master is up, copy kubeconfig to host automatically
    master.trigger.after :up do |trigger|
      trigger.name = "Getting kubeconfig..."
      trigger.info = "Copying kubeconfig to host machine"
      trigger.run_remote = {inline: "sudo cp /etc/kubernetes/admin.conf /vagrant/kubeconfig 2>/dev/null || true"}
    end
  end

  # Frontend Node
  config.vm.define "k8s-frontend" do |frontend|
    setup_node(frontend, "k8s-frontend", frontend_ip, master_ip)
    frontend.vm.provision "shell", path: "./scripts/setup-worker.sh"
#    frontend.vm.provision "shell", path: "kubectl label node k8s-frontend tier=frontend --overwrite"
  end

  # Backend Node
  config.vm.define "k8s-backend" do |backend|
    setup_node(backend, "k8s-backend", backend_ip, master_ip)
    backend.vm.provision "shell", path: "./scripts/setup-worker.sh"
#    backend.vm.provision "shell", path: "kubectl label node k8s-backend tier=backend --overwrite"
  end

  # Database Node
  config.vm.define "k8s-database" do |database|
    setup_node(database, "k8s-database", database_ip, master_ip)
    database.vm.provision "shell", path: "./scripts/setup-worker.sh"
#    database.vm.provision "shell", path: "kubectl label node k8s-database tier=database --overwrite"
  end
end
