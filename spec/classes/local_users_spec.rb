require 'spec_helper'

describe 'local_users' do
  let(:pre_condition) do
    <<~PUPPET
      function vault_msi::kv_get(String $path, String $mount) >> Hash {
        assert_type(Enum['secret-restricted'], $mount)
        $result = $path ? {
          'puppet/local_users/hashes' => {
            'root' => '$6$/dBBM855e2zWLTa6$YiP9qjLYyDyMiBnDRg9Buxg4xKcmOFqCx6zYbd4HaJthZ92ybpUTIu8vcZw63wvngutvD7vHjuYldIa/ktAK6/',
          },
          'puppet/local_users/pubkeys' => {
            'root' => 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK1rootConsoleKey root@console',
            'root-recovery' => 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrootRecoveryKey root@recovery',
            'another.console' => 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtherUsersKey another@console',
          },
          default => fail("unexpected Vault path ${path}"),
        }
        $result
      }
    PUPPET
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      # Dependent on number of users in spec/fixtures/hiera/common.yaml
      it { is_expected.to have_user_resource_count(1) }

      it do
        is_expected.to contain_user('root').with(
          'password' => sensitive('$6$/dBBM855e2zWLTa6$YiP9qjLYyDyMiBnDRg9Buxg4xKcmOFqCx6zYbd4HaJthZ92ybpUTIu8vcZw63wvngutvD7vHjuYldIa/ktAK6/'),
        )
      end

      it { is_expected.to have_ssh_authorized_key_resource_count(2) }

      it do
        is_expected.to contain_ssh_authorized_key('root').with(
          'user' => 'root',
          'type' => 'ssh-ed25519',
          'key'  => 'AAAAC3NzaC1lZDI1NTE5AAAAIK1rootConsoleKey',
        )
      end

      it do
        is_expected.to contain_ssh_authorized_key('root-recovery').with(
          'user' => 'root',
          'type' => 'ssh-rsa',
          'key'  => 'AAAAB3NzaC1yc2EAAAADAQABAAABAQCrootRecoveryKey',
        )
      end
    end
  end
end
