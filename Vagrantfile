# -*- mode: ruby -*-
# vi: set ft=ruby :

if Vagrant.has_plugin?('vagrant-triggers')
  triggers = true
end
Vagrant.configure("2") do |config|

  config.vm.box = "scotch/box"
  config.vm.network "private_network", ip: "192.168.33.10"
  config.vm.hostname = "scotchbox"
  config.vm.synced_folder "c:/dev/www", "/var/www", :mount_options => ["dmode=777", "fmode=666"]
  config.vm.provider "virtualbox" do |v|
      v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]
      v.customize ["modifyvm", :id, "--memory", 512]
  end

	config.ssh.insert_key = false

	config.vm.provision "shell" do |script|
  	script.path = "provisioner.sh"
	end

  if triggers
    config.trigger.before :status do
      run "destroy.sh"
    end
  end

end
