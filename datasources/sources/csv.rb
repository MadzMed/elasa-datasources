# frozen_string_literal: true
# typed: true

require 'csv'
require 'http'
require 'active_support/all'

require 'sorbet-runtime'

require_relative 'source'


class CsvSource < Source
  def initialize(source_id, attribution, settings, path)
    super(source_id, attribution, settings, path)
    @url = settings['url']
    @col_sep = settings['col_sep']
    @id = settings['id']
    @lon = settings['lon']
    @lat = settings['lat']
    @timestamp = settings['timestamp']
  end

  def fetch(url, col_sep)
    resp = HTTP.follow.get(url)
    if !resp.status.success?
      raise [url, resp].inspect
    end

    CSV.parse(resp.body.to_s, headers: true, col_sep: col_sep, quote_char: nil).each(&:to_h)
  end

  def each
    raw = fetch(@url, @col_sep)
    puts "#{self.class.name}: #{raw.size}"

    raw.select{ |r|
      r[@id].present? && r[@lon].present? && r[@lat].present?
    }.each{ |r|
      yield ({
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [r[@lon].to_f, r[@lat].to_f],
        },
        properties: {
          id: r[@id].to_i,
          updated_at: r[@timestamp],
          source: @attribution,
          tags: r.to_h.except(@id, @lon, @lat, @timestamp).compact_blank
        }.compact_blank
      })
    }
  end
end