Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64" 
  config.vm.define "host1" do |host1| 
    host1.vm.hostname = "host1" 
    host1.vm.network "private_network", ip: "192.168.56.10" 
  end 

  config.vm.define "host2" do |host2| 
    host2.vm.hostname = "host2" 
    host2.vm.network "private_network", ip: "192.168.56.20" 
  end

  config.vm.define "server" do |server|
    server.vm.hostname = "server"
    server.vm.network "private_network", ip: "192.168.56.30"
  end

  config.vm.define "client" do |client|
    client.vm.hostname = "client"
    client.vm.network "private_network", ip: "192.168.56.40"
  end
 
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "ansible/provision.yaml"
  end

end

