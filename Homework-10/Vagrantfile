MACHINES = {
  :"lesson12" => {
    :box_name => "generic/centos8s",
    :cpus => 8,
    :memory => 16384,
  }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant"
    config.vm.network "public_network", auto_config: false
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxname.to_s
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
    end
    config.vm.provision "ansible" do |ansible|
      ansible.playbook = "auto_configuration.yaml"
    end
  end
end

