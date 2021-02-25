require 'spec_helper_acceptance'

describe 'sudo::conf class' do
  context 'with default parameters' do
    # Using puppet_apply as a helper
    it 'works with no errors' do
      pp = <<-PP
      group { 'janedoe':
        ensure => present;
      }
      ->
      user { 'janedoe' :
        gid => 'janedoe',
        home => '/home/janedoe',
        shell => '/bin/bash',
        managehome => true,
        membership => minimum,
      }
      ->
      user { 'nosudoguy' :
        home => '/home/nosudoguy',
        shell => '/bin/bash',
        managehome => true,
        membership => minimum,
      }
      ->
      class {'sudo':
        purge               => false,
        config_file_replace => false,
      }
      ->
      sudo::conf { 'janedoe_nopasswd':
        content => "janedoe ALL=(ALL) NOPASSWD: ALL\n"
      }
      PP

      # Run it twice and test for idempotency
      apply_manifest(pp, :catch_failures => true)
      apply_manifest(pp, :catch_failures => true)
    end

    describe command("su - janedoe -c 'sudo echo Hello World'") do
      its(:stdout) { is_expected.to match %r{Hello World} }
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe command("su - nosudoguy -c 'sudo echo Hello World'") do
      its(:stderr) { is_expected.to match %r{no tty present and no askpass program specified} }
      its(:exit_status) { is_expected.to eq 1 }
    end
  end

  context 'with ignore and suffix specified' do
    describe command('touch /etc/sudoers.d/file-from-rpm') do
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe 'create a puppet managed file' do
      pp = <<-PP
      class {'sudo':
        suffix => '_puppet',
        ignore => '[*!_puppet]',
      }
      sudo::conf { 'janedoe_nopasswd':
        content => "janedoe ALL=(ALL) NOPASSWD: ALL\n"
      }
      PP

      # Run it twice and test for idempotency
      it 'runs with out errors' do
        apply_manifest(pp, :catch_failures => true)
        expect(apply_manifest(pp, :catch_failures => true).exit_code).to be_zero
      end
      describe file('/etc/sudoers.d/janedoe_nopasswd_puppet') do
        it { is_expected.to exist }
      end
      describe file('/etc/sudoers.d/sudoers.d/file-from-rpm') do
        it { is_expected.to exist }
      end
      pp = <<-PP
      class {'sudo':
        suffix => '_puppet',
        ignore => '[*!_puppet]',
      }
      PP
      # Run it twice and test for idempotency
      it 'runs with no changes' do
        apply_manifest(pp, :catch_failures => true)
        expect(apply_manifest(pp, :catch_changes => true).exit_code).to be_zero
      end
      describe file('/etc/sudoers.d/janedoe_nopasswd_puppet') do
        it { is_expected.not_to exist }
      end
      describe file('/etc/sudoers.d/sudoers.d/file-from-rpm') do
        it { is_expected.to exist }
      end
    end
  end
end
