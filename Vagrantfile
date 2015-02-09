VAGRANTFILE_API_VERSION = "2"
# CHEF_SOLO_PROJECT_PATH = "/Users/petrklimenko/Dropbox/WebDev/devops/chef-solo"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.define :siebconf do |sc|

    # Every Vagrant virtual environment requires a box to build off of.
    sc.vm.box = "ubuntu/trusty64"

    # Disable automatic box update checking. If you disable this, then
    # boxes will only be checked for updates when the user runs
    # `vagrant box outdated`. This is not recommended.
    # sc.vm.box_check_update = false

    # Share an additional folder to the guest VM. The first argument is
    # the path on the host to the actual folder. The second argument is
    # the path on the guest to mount the folder. And the optional third
    # argument is a set of non-required options.
    # sc.vm.synced_folder ".", "/var/www/siebconf"
    # sc.vm.synced_folder "/", "/mac"
    sc.vm.synced_folder '.', '/vagrant', disabled: true
    sc.vm.synced_folder '.', '/home/vagrant/siebconf'

    sc.vm.provider "virtualbox" do |vb|
      vb.name = "siebconfig"
      vb.memory = 2048
      vb.cpus = 2
    end

    # sc.vm.provision "chef_solo" do |chef|

    #   chef.environments_path = "#{CHEF_SOLO_PROJECT_PATH}/environments"
    #   chef.cookbooks_path = [
    #     "#{CHEF_SOLO_PROJECT_PATH}/cookbooks",
    #     "#{CHEF_SOLO_PROJECT_PATH}/site-cookbooks"
    #   ]
    #   chef.roles_path = "#{CHEF_SOLO_PROJECT_PATH}/roles"
    #   chef.data_bags_path = "#{CHEF_SOLO_PROJECT_PATH}/data_bags"

    #   environment = "development"

    #   chef.add_role "server"
    #   chef.add_role "java"
    #   chef.add_role "rails-app"
    #   chef.add_role "nginx-server"
    #   chef.add_role "mongo-server"
      
    #   # You may also specify custom JSON attributes:
    #   # chef.json = { mysql_password: "foo" }

    # end

    # Create a forwarded port mapping which allows access to a specific port
    # within the machine from a port on the host machine. In the example below,
    # accessing "localhost:8080" will access port 80 on the guest machine.
    sc.vm.network "forwarded_port", guest: 80, host: 8080
    sc.vm.network "forwarded_port", guest: 3000, host: 3000
    sc.vm.network "forwarded_port", guest: 27017, host: 27017
  
    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    # sc.vm.network "private_network", ip: "192.168.33.10"

    # Create a public network, which generally matched to bridged network.
    # Bridged networks make the machine appear as another physical device on
    # your network.
    # sc.vm.network "public_network"

    # If true, then any SSH connections made will enable agent forwarding.
    # Default value: false
    # sc.ssh.forward_agent = true    

  end
end
