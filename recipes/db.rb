include_recipe "hive2::_configure"
include_recipe "java"

private_ip = my_private_ip()

bash 'setup-hive' do
  user "root"
  group node['hive2']['group']
  code <<-EOH
        #{node['ndb']['scripts_dir']}/mysql-client.sh -e \"CREATE DATABASE IF NOT EXISTS metastore CHARACTER SET latin1\"
        #{node['ndb']['scripts_dir']}/mysql-client.sh -e \"GRANT ALL PRIVILEGES ON metastore.* TO '#{node['hive2']['mysql_user']}'@'#{private_ip}' IDENTIFIED BY '#{node['hive2']['mysql_password']}'\"
        #{node['ndb']['scripts_dir']}/mysql-client.sh -e \"GRANT ALL PRIVILEGES ON metastore.* TO '#{node['hive2']['mysql_user']}'@'#{node['hostname']}' IDENTIFIED BY '#{node['hive2']['mysql_password']}'\"
        #{node['ndb']['scripts_dir']}/mysql-client.sh -e \"GRANT SELECT ON hops.hdfs_inodes TO '#{node['hive2']['mysql_user']}'@'#{private_ip}' IDENTIFIED BY '#{node['hive2']['mysql_password']}'\"
        #{node['ndb']['scripts_dir']}/mysql-client.sh -e \"GRANT SELECT ON hops.hdfs_inodes TO '#{node['hive2']['mysql_user']}'@'#{node['hostname']}' IDENTIFIED BY '#{node['hive2']['mysql_password']}'\"
        #{node['ndb']['scripts_dir']}/mysql-client.sh -e \"FLUSH PRIVILEGES\"
        EOH
  not_if "#{node['ndb']['scripts_dir']}/mysql-client.sh -e \"SHOW DATABASES\" | grep metastore"
end

# If the tables exist, then try the update
bash 'schematool' do
  user node['hive2']['user']
  group node['hive2']['group']
  code <<-EOH
      #{node['hive2']['base_dir']}/bin/schematool -dbType mysql -upgradeSchema
  EOH
  only_if "#{node['ndb']['scripts_dir']}/mysql-client.sh -e \"use metastore; SHOW TABLES;\" | grep -i SDS"
end

# If the tables do not exist, then init the schema
bash 'schematool' do
  user node['hive2']['user']
  group node['hive2']['group']
  code <<-EOH
      #{node['hive2']['base_dir']}/bin/schematool -dbType mysql -initSchema
  EOH
  not_if "#{node['ndb']['scripts_dir']}/mysql-client.sh -e \"use metastore; SHOW TABLES;\" | grep -i SDS"
end


