# frozen_string_literal: true

require "test_helper"

class ProjectTest < Minitest::Test
  def test_configuration_is_bound_to_explicit_root_and_immutable
    in_project("generated_paths" => ["man", "test/fixtures/golden"]) do |project|
      assert_equal "sample-cli", project.name
      assert_equal "https://github.com/example/sample-cli", project.url
      assert_equal File.join(project.root, "lib/sample_cli/version.rb"), project.path(project.version_file)
      assert_includes project.release_files, "test/fixtures/golden"
      assert_predicate project, :frozen?
      assert_raises(FrozenError) { project.check_command.first.replace("bad") }
    end
  end

  def test_rejects_unknown_settings_and_schema
    assert_raises(RubyRepoKit::Error) { in_project("scheam" => 1) { flunk } }
    assert_raises(RubyRepoKit::Error) { in_project("schema" => 2) { flunk } }
    assert_raises(RubyRepoKit::Error) { in_project("name" => "../../bad") { flunk } }
    assert_raises(RubyRepoKit::Error) { in_project("repository" => "--repo=other") { flunk } }
  end

  def test_rejects_paths_outside_root_and_shell_string_commands
    ["../secret", "/tmp/secret", "a/../secret", "./version.rb", "a\0b"].each do |path|
      assert_raises(RubyRepoKit::Error) { in_project("version_file" => path) { flunk } }
    end
    assert_raises(RubyRepoKit::Error) { in_project("check_command" => "rake && publish") { flunk } }
    assert_raises(RubyRepoKit::Error) { in_project("generate_command" => []) { flunk } }
  end

  def test_does_not_follow_symlinks_outside_the_project
    in_project do |project|
      Dir.mktmpdir do |external|
        File.symlink(external, project.path("escape"))
        assert_raises(RubyRepoKit::Error) { project.path("escape/version.rb") }
        assert_raises(RubyRepoKit::Error) { project.path("escape") }
      end
    end
  end

  def test_rejects_yaml_object_loading_and_aliases
    Dir.mktmpdir do |root|
      path = File.join(root, RubyRepoKit::Project::CONFIG_FILE)
      File.write(path, "--- !ruby/object:Object {}\n")
      assert_raises(RubyRepoKit::Error) { RubyRepoKit::Project.load(root: root) }
      File.write(path, "schema: 1\nname: &name sample-cli\nrepository: *name\n")
      assert_raises(RubyRepoKit::Error) { RubyRepoKit::Project.load(root: root) }
    end
  end
end
