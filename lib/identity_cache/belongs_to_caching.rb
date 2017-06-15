module IdentityCache
  module BelongsToCaching
    extend ActiveSupport::Concern

    included do |base|
      base.class_attribute :cached_belongs_tos
      base.cached_belongs_tos = {}
    end

    module ClassMethods
      def cache_belongs_to(association)
        ensure_base_model

        unless association_reflection = reflect_on_association(association)
          raise AssociationError, "Association named '#{association}' was not found on #{self.class}"
        end
        if association_reflection.scope
          raise UnsupportedAssociationError, "caching association #{self}.#{association} is scoped which isn't supported"
        end

        options = {}
        self.cached_belongs_tos[association] = options

        options[:embed]                   = false
        options[:cached_accessor_name]    = "fetch_#{association}"
        options[:records_variable_name]   = "cached_#{association}"
        options[:association_reflection]  = association_reflection
        options[:prepopulate_method_name] = "prepopulate_fetched_#{association}"

        build_normalized_belongs_to_cache(association, options)
      end

      private

      def build_normalized_belongs_to_cache(association_name, options)
        foreign_key = options[:association_reflection].foreign_key
        self.class_eval(<<-CODE, __FILE__, __LINE__ + 1)
          def #{options[:cached_accessor_name]}
            return #{association_name} unless #{foreign_key}
            fetch_cached_association(:#{association_name}, :@#{options[:records_variable_name]}) do |association|
              association.klass.fetch_by_id(#{foreign_key})
            end
          end

          def #{options[:prepopulate_method_name]}(record)
            @#{options[:records_variable_name]} = record
          end
        CODE
      end
    end
  end
end
