class Pry
  class PluginManager
    PRY_PLUGIN_PREFIX = /^pry-/
    PluginNotFound = Class.new(LoadError)

    MessageSink = Object.new.tap { |o| def o.method_missing(*args) end }

    class Plugin
      attr_accessor :name, :gem_name, :enabled, :spec, :active

      def initialize(name, gem_name, spec, enabled)
        @name, @gem_name, @enabled, @spec = name, gem_name, enabled, spec
      end

      # Disable a plugin.
      def disable!
        self.enabled = false
      end

      # Enable a plugin.
      def enable!
        self.enabled = true
      end

      # Activate the plugin (require the gem).
      def activate!
        begin
          require gem_name
        rescue LoadError
          $stderr.puts "Warning: The plugin '#{gem_name}' was not found!"
        end
        self.active = true
        self.enabled = true
      end

      alias active? active
      alias enabled? enabled
    end

    def initialize
      @plugins = []
    end

    # Find all installed Pry plugins and store them in an internal array.
    def locate_plugins
      Gem.refresh
      (Gem::Specification.respond_to?(:each) ? Gem::Specification : Gem.source_index.find_name('')).each do |gem|
        next if gem.name !~ PRY_PLUGIN_PREFIX
        plugin_name = gem.name.split('-', 2).last
        @plugins << Plugin.new(plugin_name, gem.name, gem, true) if !gem_located?(gem.name)
      end
      @plugins
    end

    # @return [Hash] A hash with all plugin names (minus the 'pry-') as
    #   keys and Plugin objects as values.
    def plugins
      h = Pry.config.plugins.strict_loading ? {} : Hash.new { MessageSink }
      @plugins.each do |plugin|
        h[plugin.name] = plugin
      end
      h
    end

    # Require all enabled plugins, disabled plugins are skipped.
    def load_plugins
      @plugins.each do |plugin|
        plugin.activate! if plugin.enabled?
      end
    end

    private
    def gem_located?(gem_name)
      @plugins.any? { |plugin| plugin.gem_name == gem_name }
    end
  end

end

