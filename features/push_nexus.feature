Feature: push_nexus
  puppet-blacksmith needs to push modules to Nexus instance

  @skip
  Scenario: Pushing a module to Nexus
    Given a file named "Rakefile" with:
    """
    require 'puppetlabs_spec_helper/rake_tasks'
    require "#{File.dirname(__FILE__)}/../../lib/puppet_blacksmith/rake_tasks"
    """
    And a file named "Modulefile" with:
    """
    name 'maestrodev-test'
    version '1.0.0'

    author 'Ontotext-AD'
    license 'Apache License, Version 2.0'
    project_page 'https://github.com/Ontotext-AD/puppet-blacksmith'
    source 'https://github.com/Ontotext-AD/puppet-blacksmith'
    summary 'Testing Puppet module operations'
    description 'Testing Puppet module operations'
    """
    When I run `rake module:push_nexus`
    Then the exit status should be 0
