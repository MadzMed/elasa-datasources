# frozen_string_literal: true
# typed: true

require 'sorbet-runtime'

require_relative 'connector'
require_relative '../sources/tourinsoft'


class Tourinsoft < Connector
  def initialize(source_class, multi_source_id, settings, source_filter, path)
    super(multi_source_id, settings, source_filter, path)
    @source_class = source_class
  end

  def each
    @settings['syndications'].select{ |name, _syndication|
      source_filter.nil? || name.start_with?(source_filter)
    }.each{ |name, syndication|
      yield [
        self,
        name,
        [@source_class, @settings.merge({ 'syndication' => syndication })]
      ]
    }
  end
end
