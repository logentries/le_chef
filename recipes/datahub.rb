#
# Author:: Joe Heung <joe.heung@logentries.com>
# Author:: Michael D'Auria <michaeld@crowdtap.com>
# Cookbook Name:: le_chef
# Recipe:: datahub
#
# Copyright 2014 Logentries, JLizard
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if platform_family?('rhel')
  raise NotImplementedError # requires more work since there is no rpm
end

if platform_family?('debian')
  datahub_package = "DataHub_#{node['le']['datahub']['version']}.deb"

  remote_file "/tmp/#{datahub_package}" do
    action :create_if_missing
    source "http://rep.logentries.com/datahub/#{datahub_package}"
    mode 0644
    checksum node['le']['datahub']['checksum']
  end

  dpkg_package "DataHub" do
    source "/tmp/#{datahub_package}"
    action :install
  end
end

service 'leproxy' do
  supports :stop => true, :start => true, :restart => true
  action :nothing
end

# The leproxy caches several logentries-server-side settings in its config file
# on start. As such, we wish to only rewrite it when we changed something
# as opposed to on every run (due to the rewriting by the deamon itself). To
# achieve this, we will make another 'seed' file and copy that one into place
# and do a restart if it changes (or the real config doesn't exist)
seed_config = "#{node['le']['datahub']['local_path']}/leproxy.config.chef"
real_config = "#{node['le']['datahub']['local_path']}/leproxy.config"

template seed_config do
  source 'etc/leproxy/leproxy.config.erb'
  variables( node['le']['datahub'].to_hash.tap do |h|
              h[:user_key] = node['le']['account_key']
            end)
  notifies :create, "file[#{real_config}]", :immediately
end

file real_config do
  content( lazy { IO.read(seed_config) } )
  action :create_if_missing
  notifies :restart, 'service[leproxy]'
end

