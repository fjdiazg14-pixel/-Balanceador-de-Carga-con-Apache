Vagrant.configure("2") do |config|
  config.ssh.username = "vagrant"
  config.ssh.password = "vagrant"
  config.ssh.insert_key = false

  cmd_arranque = ["bash", "-c", "apt-get update && apt-get install -y openssh-server sudo && mkdir -p /run/sshd && (id vagrant || useradd -m -s /bin/bash vagrant) && echo 'vagrant:vagrant' | chpasswd && echo 'vagrant ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vagrant && /usr/sbin/sshd -D"]

  config.vm.define "base_datos" do |bd|
    bd.vm.hostname = "FranciscoJavierDiazGarronBBDD"

    bd.vm.provider "docker" do |d|
      d.name = "FranciscoJavierDiazGarronBBDD"
      d.image = "debian:bookworm"
      d.has_ssh = true
      d.privileged = true
      d.remains_running = true
      d.cmd = cmd_arranque
      d.create_args = ["--network=red_bbdd", "--ip=172.20.2.20"]
    end

    bd.vm.provision "shell", path: "scripts/aprovisionamiento_bd.sh"
  end

  config.vm.define "web1" do |w1|
    w1.vm.hostname = "FranciscoJavierDiazGarronWeb1"

    w1.vm.provider "docker" do |d|
      d.name = "FranciscoJavierDiazGarronWeb1"
      d.image = "debian:bookworm"
      d.has_ssh = true
      d.privileged = true
      d.remains_running = true
      d.cmd = cmd_arranque
      d.create_args = ["--network=red_web", "--ip=172.20.1.21"]
    end

    w1.vm.provision "shell", path: "scripts/aprovisionamiento_web.sh", args: ["Servidor Web 1"]
  end

  config.vm.define "web2" do |w2|
    w2.vm.hostname = "FranciscoJavierDiazGarronWeb2"

    w2.vm.provider "docker" do |d|
      d.name = "FranciscoJavierDiazGarronWeb2"
      d.image = "debian:bookworm"
      d.has_ssh = true
      d.privileged = true
      d.remains_running = true
      d.cmd = cmd_arranque
      d.create_args = ["--network=red_web", "--ip=172.20.1.22"]
    end

    w2.vm.provision "shell", path: "scripts/aprovisionamiento_web.sh", args: ["Servidor Web 2"]
  end

  config.vm.define "balanceador" do |bal|
    bal.vm.hostname = "FranciscoJavierDiazGarronBalanceador"
    bal.vm.network "forwarded_port", guest: 80, host: 8080
    bal.vm.network "forwarded_port", guest: 443, host: 8443

    bal.vm.provider "docker" do |d|
      d.name = "FranciscoJavierDiazGarronBalanceador"
      d.image = "debian:bookworm"
      d.has_ssh = true
      d.privileged = true
      d.remains_running = true
      d.cmd = cmd_arranque
      d.create_args = ["--network=red_web", "--ip=172.20.1.10"]
    end

    bal.vm.provision "shell", path: "scripts/aprovisionamiento_balanceador.sh"
  end
end
