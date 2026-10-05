# frozen_string_literal: true

module PackageFixtures
  def write_gem(project)
    FileUtils.mkdir_p(project.path("lib/sample_cli"))
    FileUtils.mkdir_p(project.path("exe"))
    File.write(project.path("lib/sample_cli/version.rb"), "module SampleCLI; VERSION = '0.1.0'; end\n")
    File.write(project.path("lib/sample_cli.rb"), "require_relative 'sample_cli/version'\n")
    File.write(project.path("exe/sample-cli"), <<~RUBY)
      #!#{RbConfig.ruby}
      require 'sample_cli'
      puts(ARGV == ['--version'] ? "sample-cli \#{SampleCLI::VERSION}" : 'Usage: sample-cli [TEXT]')
    RUBY
    File.chmod(0o755, project.path("exe/sample-cli"))
    File.write(project.path("sample-cli.gemspec"), <<~RUBY)
      require_relative 'lib/sample_cli/version'
      Gem::Specification.new do |spec|
        spec.name = 'sample-cli'
        spec.version = SampleCLI::VERSION
        spec.authors = ['Test']
        spec.summary = 'A temporary package fixture'
        spec.license = 'MIT'
        spec.homepage = 'https://example.org/sample-cli'
        spec.files = Dir.chdir(__dir__) { Dir['lib/**/*.rb', 'exe/*'] }
        spec.bindir = 'exe'
        spec.executables = ['sample-cli']
      end
    RUBY
  end
end
