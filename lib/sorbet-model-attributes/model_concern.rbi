# typed: strict

class ActiveRecord::Base
  extend SorbetModelAttributes::ModelConcern::ClassMethods
end

module SorbetModelAttributes
  module ModelConcern
    module ClassMethods
      sig { params(column_name: T.any(Symbol, String), struct_class: T.class_of(T::Struct), optional: T::Boolean).void }
      def sorbet_attributes(column_name, struct_class, optional: false); end
    end
  end
end
