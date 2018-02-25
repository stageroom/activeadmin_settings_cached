# frozen_string_literal: true

module ActiveadminSettingsCached
  module ModelHelpers
    TIME_FORMAT = '%Y-%m-%d %H:%M'

    def time_value(value)
      return value unless value.is_a?(Time)
      value&.strftime(TIME_FORMAT)
    end
  end

  class Model
    include ::ActiveModel::Model
    include ModelHelpers

    attr_reader :attributes

    def initialize(args = {})
      @attributes = {}
      args[:model_name] = args[:model_name].constantize if args[:model_name].is_a? String
      args[:display] = default_attributes[:display].merge!(args[:display]) if args[:display]
      assign_attributes(merge_attributes(args))
    end

    def field_name(settings_name)
      has_key? ? "#{attributes[:key]}.#{settings_name}" : settings_name
    end

    def field_options(settings_name, key_name)
      default_value = defaults[settings_name]
      value = settings[key_name]

      input_opts = if default_value.is_a?(Array)
                     {
                       collection: default_value,
                       selected: value,
                     }
                   elsif default_value.is_a?(Time)
                     {
                         input_html: { value: time_value(value), placeholder: time_value(default_value) }
                     }
                   elsif (default_value.is_a?(TrueClass) || default_value.is_a?(FalseClass)) &&
                         display[settings_name].to_s == 'boolean'
                     {
                       input_html: { checked: value }, label: '', checked_value: 'true', unchecked_value: 'false'
                     }
                   else
                     {
                       input_html: { value: value, placeholder: default_value },
                     }
                   end

      display_options(settings_name, { label: false })
          .merge!(input_opts)
    end

    def settings
      data = has_key? ? load_settings_by_key : load_settings
      return unless data

      ::ActiveSupport::OrderedHash[data.to_a.sort { |a, b| a.first <=> b.first }]
    end

    def defaults
      settings_model.respond_to?(:defaults) ?
          settings_model.defaults :
          ::RailsSettings::Default
    end

    def defaults_keys
      settings_model.respond_to?(:defaults) ?
          settings_model.defaults.keys :
          ::RailsSettings::Default.instance.keys
    end

    def display
      attributes[:display]
    end

    def [](param)
      settings_model[param]
    end

    def []=(param, value)
      settings_model[param] = value
    end

    def save(key, value)
      if has_key?
        settings_model.merge!(attributes[:key], { clean_key(key) => value })
      else
        self[key] = value
      end
    end

    def persisted?
      false
    end

    alias_method :to_hash, :attributes

    protected

    def display_options(settings_name, opts)
      return opts unless display[settings_name]

      if display[settings_name].is_a?(Hash)
        opts.merge!(display[settings_name].symbolize_keys)
      else
        opts[:as] = display[settings_name]
      end

      opts
    end

    def load_settings
      settings_model.public_send(meth, attributes[:starting_with])
    end

    def load_settings_by_key
      self[attributes[:key]]
    end

    def has_key?
      attributes[:key].present?
    end

    def clean_key(key)
      key.is_a?(Symbol) ? key : "#{key.sub("#{attributes[:key]}.", '')}"
    end

    def assign_attributes(args = {})
      @attributes.merge!(args)
    end

    def default_attributes
      {
        starting_with: nil,
        key: nil,
        model_name: ::ActiveadminSettingsCached.config.model_name,
        display: ::ActiveadminSettingsCached.config.display
      }
    end

    def merge_attributes(args)
      default_attributes.each_with_object({}) do |(k, v), h|
        h[k] = args[k] || v
      end
    end

    def settings_model
      attributes[:model_name]
    end

    def meth
      if Rails.version >= '4.1.0'
        :get_all
      else
        :all
      end
    end
  end
end
