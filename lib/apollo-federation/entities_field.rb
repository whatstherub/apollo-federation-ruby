# frozen_string_literal: true

require 'graphql'
require 'apollo-federation/any'
require 'apollo-federation/entity_type_resolution_extension'

module ApolloFederation
  module EntitiesField
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      extend GraphQL::Schema::Member::HasFields

      def define_entities_field(possible_entities)
        # If there are any "entities", define the Entity union and and the Query._entities field
        return if possible_entities.empty?

        entity_type = Class.new(Entity) do
          possible_types(*possible_entities)
        end

        field(:_entities, [entity_type, null: true], null: false) do
          argument :representations, [Any], required: true
          extension(EntityTypeResolutionExtension)
        end
      end
    end

    def _entities(representations:)
      representations.map do |reference|
        typename = reference[:__typename]
        # TODO: Use warden or schema?
        type = context.warden.get_type(typename)
        if type.nil? || type.kind != GraphQL::TypeKinds::OBJECT
          # TODO: Raise a specific error class?
          raise "The _entities resolver tried to load an entity for type \"#{typename}\"," \
                ' but no object type of that name was found in the schema'
        end

        # TODO: What if the type is an interface?
        type_class = type.is_a?(GraphQL::ObjectType) ? type.metadata[:type_class] : type
        if type_class.respond_to?(:resolve_reference)
          result = type_class.resolve_reference(reference, context)
        else
          result = reference
        end

        [type, result]
      end
    end
  end
end
