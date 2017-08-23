require 'rake'
require 'rake/tasklib'
require 'puppet_blacksmith'

module Blacksmith
  class RakeTask < ::Rake::TaskLib
    attr_accessor :tag_pattern, :build

    def initialize(*args, &task_block)
      @build = true
      @task_name = args.shift || 'blacksmith'
      @desc = args.shift || 'Puppet Forge utilities'
      define(args, &task_block)
    end

    def define(args, &task_block)
      yield(*[self, args].slice(0, task_block.arity)) if task_block

      # clear any (auto-)pre-existing task
      [
        :bump,
        'bump:major',
        'bump:minor',
        'bump:patch',
        'bump:full',
        :tag,
        :version,
        'version:next',
        'version:next:major',
        'version:next:minor',
        'version:next:patch',
        :bump_commit,
        'bump_commit:major',
        'bump_commit:minor',
        'bump_commit:patch',
        'bump_commit:full',
        :push,
        :push_nexus,
        :clean,
        :release,
        :release_nexus,
        :dependency
      ].each do |t|
        Rake::Task.task_defined?("module:#{t}") && Rake::Task["module:#{t}"].clear
      end

      namespace :module do
        namespace :bump do
          %i[major minor patch full].each do |level|
            desc "Bump module version to the next #{level.upcase} version"
            task level do
              m = Blacksmith::Modulefile.new
              v = m.send("bump_#{level}!")
              puts "Bumping version from #{m.version} to #{v}"
            end
          end
        end

        desc 'Bump module version to the next patch'
        task :bump do
          m = Blacksmith::Modulefile.new
          v = m.bump_patch!
          puts "Bumping version from #{m.version} to #{v}"
        end

        desc 'Git tag with the current module version'
        task :tag do
          m = Blacksmith::Modulefile.new
          git = Blacksmith::Git.new
          git.tag_pattern = @tag_pattern
          git.tag!(m.version)
        end

        namespace :version do
          desc 'Get next module version'
          task :next do
            m = Blacksmith::Modulefile.new
            puts m.increase_version(m.version, 'patch')
          end

          %i[major minor patch].each do |level|
            desc "Get the next #{level.upcase} version"
            task "next:#{level}".to_sym do
              m = Blacksmith::Modulefile.new
              puts m.increase_version(m.version, level)
            end
          end
        end

        desc 'Get current module version'
        task :version do
          m = Blacksmith::Modulefile.new
          puts m.version
        end

        namespace :bump_commit do
          %i[major minor patch full].each do |level|
            desc "Bump module version to the next #{level.upcase} version and git commit"
            task level => "bump:#{level}".to_sym do
              m = Blacksmith::Modulefile.new
              Blacksmith::Git.new.commit_modulefile!(m.version)
            end
          end
        end

        desc 'Bump version and git commit'
        task bump_commit: :bump do
          m = Blacksmith::Modulefile.new
          Blacksmith::Git.new.commit_modulefile!(m.version)
        end

        desc 'Push module to the Puppet Forge'
        task push: :build do
          m = Blacksmith::Modulefile.new
          forge = Blacksmith::Forge.new
          puts "Uploading to Puppet Forge #{forge.username}/#{m.name}"
          forge.push!(m.name)
        end

        desc 'Push module to the Nexus instance'
        task push_nexus: :build do
          m = Blacksmith::Modulefile.new
          nexus = Blacksmith::Nexus.new
          puts "Uploading to Nexus Instance #{nexus.url}"
          nexus.push!(m.name)
        end

        desc 'Runs clean again'
        task :clean do
          puts 'Cleaning for module build'
          Rake::Task['clean'].execute
        end

        desc 'Release the Puppet module, doing a clean, build, tag, push, bump_commit and git push.'
        release_dependencies = @build ? %i[clean build bump_commit tag push] : %i[clean bump_commit tag]
        task release: release_dependencies do
          puts 'Pushing to remote git repo'
          Blacksmith::Git.new.push!
        end

        desc 'Release the Puppet module, doing a clean, build, tag, push_nexus, bump_commit and git push.'
        release_dependencies = @build ? %i[clean build bump_commit tag push_nexus] : %i[clean bump_commit tag]
        task release_nexus: release_dependencies do
          puts 'Pushing to remote git repo'
          Blacksmith::Git.new.push!
        end

        desc 'Set specific module dependency version'
        task :dependency, %i[module_name version] do |_t, args|
          mn = args[:module_name]
          mv = args[:version]
          m = Blacksmith::Modulefile.new
          m.bump_dep! mn, mv
          puts "Updated module dependency #{mn} to #{mv}"
        end
      end
    end
  end
end

Blacksmith::RakeTask.new
