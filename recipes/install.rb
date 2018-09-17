include_recipe "java"

my_ip = my_private_ip()

group node['hive2']['group'] do
  action :create
  not_if "getent group #{node['hive2']['group']}"
end

user node['hive2']['user'] do
  home "/home/#{node['hive2']['user']}"
  action :create
  shell "/bin/bash"
  manage_home true
  system true
  not_if "getent passwd #{node['hive2']['user']}"
end

group node['hive2']['group'] do
  action :modify
  members node['hive2']['user']
  append true
end

group node['kagent']['certs_group'] do
  action :create
  not_if "getent group #{node['kagent']['certs_group']}"
end

group node['kagent']['certs_group'] do
  action :modify
  members node['hive2']['user']
  append true
end

package_url = "#{node['hive2']['url']}"
base_package_filename = File.basename(package_url)
cached_package_filename = "#{Chef::Config['file_cache_path']}/#{base_package_filename}"

remote_file cached_package_filename do
  source package_url
  owner "#{node['hive2']['user']}"
  mode "0644"
  action :create_if_missing
end

# Extract Hive
hive_downloaded = "#{node['hive2']['home']}/.hive_extracted_#{node['hive2']['version']}"

bash 'extract-hive' do
        user "root"
        group node['hive2']['group']
        code <<-EOH
                set -e
                tar zxf #{cached_package_filename} -C #{Chef::Config['file_cache_path']}
                mv #{Chef::Config['file_cache_path']}/apache-hive-#{node['hive2']['version']}-bin #{node['hive2']['dir']}
                # remove old symbolic link, if any
                rm -f #{node['hive2']['base_dir']}
                ln -s #{node['hive2']['home']} #{node['hive2']['base_dir']}
                chown -R #{node['hive2']['user']}:#{node['hive2']['group']} #{node['hive2']['home']}
                chmod 770 #{node['hive2']['home']}
                chown -R #{node['hive2']['user']}:#{node['hive2']['group']} #{node['hive2']['base_dir']}
                touch #{hive_downloaded}
                chown -R #{node['hive2']['user']}:#{node['hive2']['group']} #{hive_downloaded}
        EOH
     not_if { ::File.exists?( "#{hive_downloaded}" ) }
end

# Install the mysql-jdbc connector
remote_file "#{node['hive2']['base_dir']}/lib/mysql-connector-java-#{node['hive2']['mysql_connector_version']}-bin.jar" do
  source node['hive2']['mysql_connector_url']
  checksum node['hive2']['mysql_connector_checksum']
  owner node['hive2']['user']
  group node['hive2']['group']
  mode '0755'
  action :create_if_missing
end
