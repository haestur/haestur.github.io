MACHINES = {
  :"packages" => {
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
    config.vm.provision "shell",
      run: "always",
      inline: "ifconfig eth1 192.168.30.9 netmask 255.255.255.0 up"
    config.vm.provision "shell",
      run: "always",
      inline: "route add default gw 192.168.30.1"
    config.vm.provision "shell",
      run: "always",
      inline: "eval `route -n | awk '{ if ($8 ==\"eth0\" && $2 != \"0.0.0.0\") print \"route del default gw \" $2; }'`"
    end
  end
end

