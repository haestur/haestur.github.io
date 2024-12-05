Vagrant .configure("2") do |config|

    config.vm.define "backupServer" do |backupServer|
        backupServer.vm.box = "ubuntu/jammy64"
        backupServer.vm.hostname = "backupServer"
        backupServer.vm.network "private_network", ip: "192.168.56.160"
        backupServer.vm.provider :virtualbox do |v|
            v.memory = 1512
            v.cpus = 2
            unless File.exist?('./disk_for_backups.vdi')
                v.customize ['createhd', '--filename', './disk_for_backups.vdi', '--variant', 'Fixed', '--size', 2000]
            end
            v.customize ['storageattach', :id,  '--storagectl', 'SCSI', '--port', 2 , '--device', 0, '--type', 'hdd', '--medium', './disk_for_backups.vdi']
        end
        backupServer.vm.provision "ansible" do |ansible|
            ansible.playbook = "server-autoconfig.yaml"
        end
    end

    config.vm.define "client" do |client|
        client.vm.box = "ubuntu/jammy64"
        client.vm.hostname = "client"
        client.vm.network "private_network", ip: "192.168.56.150"
        client.vm.provider :virtualbox do |v|
            v.memory = 1512
            v.cpus = 2
        end
       client.vm.provision "ansible" do |ansible|
           ansible.playbook = "client-autoconfig.yaml"
       end
    end

end 

