require 'fortitude/tag'
require 'fortitude/errors'

module Fortitude
  class Widget
    class << self
      def tags_module
        @tags_module ||= begin
          out = Module.new
          include(out)
          out
        end
      end

      def tag(name, options = { })
        Fortitude::Tag.new(name, options).define_method_on!(tags_module)
      end

      def needs(*variables)
        @needs ||= [ ]
        @needs |= variables.map { |v| v.to_s.strip.downcase.to_sym }

        @needs.each do |n|
          class_eval <<-EOS
  def #{n}
    @_fortitude_assign_#{n}
  end
EOS
        end

        @needs
      end
    end

    tag :html
    tag :body
    tag :head
    tag :link
    tag :style

    tag :header
    tag :nav
    tag :section
    tag :footer

    tag :script
    tag :meta
    tag :title

    tag :h1
    tag :h2
    tag :h3
    tag :h4
    tag :h5
    tag :h6

    tag :div
    tag :span

    tag :ul
    tag :ol
    tag :li

    tag :p

    tag :a
    tag :img

    tag :form
    tag :input
    tag :submit
    tag :button
    tag :label
    tag :select
    tag :optgroup
    tag :option
    tag :textarea
    tag :fieldset

    tag :table
    tag :tr
    tag :th
    tag :td

    tag :time

    tag :i
    tag :b
    tag :em
    tag :strong

    tag :br
    tag :hr

    def initialize(assigns = { })
      missing = [ ]

      self.class.needs.each do |n|
        if assigns.has_key?(n)
          instance_variable_set("@_fortitude_assign_#{n}", assigns[n])
        else
          missing << n
        end
      end

      if missing.length > 0
        raise Fortitude::Errors::MissingNeed.new(self, missing, assigns.keys)
      end
    end

    def content
      raise "Must override in #{self.class.name}"
    end

    def method_missing(name, *args, &block)
      if @_fortitude_rendering_context.helpers_object.respond_to?(name)
        effective_block = if block
          lambda do
            reload_output!
            block.call
          end
        end

        begin
          @_fortitude_rendering_context.helpers_object.send(name, *args, &effective_block)
        ensure
          reload_output!
        end
      else
        super(name, *args, &block)
      end
    end

    BEFORE_ATTRIBUTE_STRING = " ".freeze
    AFTER_ATTRIBUTE_STRING = "=\"".freeze
    AFTER_VALUE_STRING = "\"".freeze

    def _attributes(h)
      o = @_fortitude_output_buffer_holder.output_buffer

      h.each do |k,v|
        o.concat(BEFORE_ATTRIBUTE_STRING)
        k.to_s.fortitude_append_escaped_string(o)
        o.concat(AFTER_ATTRIBUTE_STRING)
        v.to_s.fortitude_append_escaped_string(o)
        o.concat(AFTER_VALUE_STRING)
      end
    end

    def yield_to_view(*args)
      @_fortitude_rendering_context.yield_to_view(*args)
    end

    def transfer_shared_variables(*args, &block)
      if self.class.implicit_shared_variable_access
        @_fortitude_rendering_context.instance_variable_set.with_instance_variable_copying(self, &block)
      end
    end

    class << self
      def implicit_shared_variable_access(on_or_off = nil)
        if on_or_off == nil
          @_fortitude_implicit_shared_variable_access || false
        elsif on_or_off
          if (! @_fortitude_implicit_shared_variable_access)
            @_fortitude_implicit_shared_variable_access = true
            around_content :transfer_shared_variables
          end
        else
          @_fortitude_implicit_shared_variable_access = false
        end
      end

      def around_content(*method_names)
        return if method_names.length == 0
        @_fortitude_around_content_methods ||= [ ]
        @_fortitude_around_content_methods += method_names.map { |x| x.to_s.strip.downcase.to_sym }
        rebuild_run_content!
      end

      private
      def this_class_around_content_methods
        @_fortitude_around_content_methods ||= [ ]
      end

      def around_content_methods
        superclass_methods = if superclass.respond_to?(:around_content_methods)
          superclass.around_content_methods
        else
          [ ]
        end

        (superclass_methods + this_class_around_content_methods).uniq
      end

      def rebuild_run_content!
        acm = around_content_methods
        text = "def run_content(*args, &block)\n"
        acm.each_with_index do |method_name, index|
          text += "  " + ("  " * index) + "#{method_name}(*args) do\n"
        end
        text += "  " + ("  " * acm.length) + "content(*args, &block)\n"
        (0..(acm.length - 1)).each do |index|
          text += "  " + ("  " * (acm.length - (index + 1))) + "end\n"
        end
        text += "end"

        class_eval(text)
      end
    end

    rebuild_run_content!

    def capture(*args, &block)
      begin
        @_fortitude_rendering_context.helpers_object.capture(*args) do
          reload_output!
          block.call
        end
      ensure
        reload_output!
      end
    end

    def content_for(*args, &block)
      begin
        net_block = nil

        if block
          net_block = lambda do
            reload_output!
            block.call
          end
        end

        @_fortitude_rendering_context.helpers_object.content_for(*args, &net_block)
      ensure
        reload_output!
      end
    end

    def provide(*args, &block)
      begin
        @_fortitude_rendering_context.helpers_object.provide(*args) do
          reload_output!
          block.call
        end
      ensure
        reload_output!
      end
    end

    def reload_output!
      @_fortitude_output = @_fortitude_rendering_context.output
    end

    def render(*args, &block)
      text @_fortitude_rendering_context.helpers_object.render(*args, &block)
      nil
    end

    def to_html(rendering_context)
      @_fortitude_rendering_context = rendering_context
      @_fortitude_output_buffer_holder = rendering_context.output_buffer_holder

      block = lambda { |*args| @_fortitude_rendering_context.yield_to_view(*args) }

      begin
        run_content(&block)
      ensure
        @_fortitude_rendering_context = nil
      end
    end

    def widget(w)
      w.to_html(@_fortitude_rendering_context)
    end

    def text(s)
      s.to_s.fortitude_append_escaped_string(@_fortitude_output_buffer_holder.output_buffer)
    end

    def rawtext(s)
      @_fortitude_output_buffer_holder.output_buffer.original_concat(s)
    end

    def shared_variables
      @_fortitude_rendering_context.instance_variable_set
    end
  end
end
