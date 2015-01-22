module Spec
  module Helpers
    module FortitudeRailsHelpers
      def rails_server_project_root
        @rails_server_project_root ||= File.expand_path(File.join(File.dirname(__FILE__), '../..'))
      end

      def rails_server_additional_gemfile_lines
        out = [
          "gem 'fortitude', :path => '#{rails_server_project_root}'"
        ]
        out << "gem 'i18n', '< 0.7.0'" if RUBY_VERSION =~ /^1\.8\./
        out
      end

      def rails_server_default_version
        ENV['FORTITUDE_SPECS_RAILS_VERSION']
      end
    end
  end
end
