# frozen_string_literal: true
# typed: false

require 'json'
require 'http'
require 'active_support/all'

require 'cgi'
require 'sorbet-runtime'
require_relative 'gdal'


class GtfsShapeSource < GdalSource
  class Settings < GdalSource::Settings
    const :gdal_command, String, default: 'ogr2ogr -f GeoJSON {{tmp_geojson}} -dialect SQLITE -sql "
      SELECT
        GUnion(DISTINCT shapes_geom.geometry) AS geometry,
        routes.*,
        group_concat(DISTINCT stops.stop_name) AS stops,
        group_concat(DISTINCT stops.stop_id||\'~\') AS stop_ids
      FROM
        shapes_geom
        JOIN trips ON
          trips.shape_id = shapes_geom.shape_id
        JOIN stop_times ON
          trips.trip_id = stop_times.trip_id
        JOIN stops ON
          stops.stop_id = stop_times.stop_id
        JOIN routes ON
          routes.route_id = trips.route_id
      GROUP BY
        routes.route_id
    " /vsicurl_streaming/{{url}}?.zip', override: true
    const :path, String # TMP FIXME to be removed
  end

  extend T::Generic
  SettingsType = type_member{ { upper: Settings } } # Generic param

  def map_id(feat)
    feat['properties']['route_id']
  end

  def map_updated_at(_feat)
    '1970'
  end

  def map_tags(feat)
    r = feat['properties']
    ref = r['route_short_name']
    {
      # type: :route,
      # route: :bus,
      ref: { ref: ref }.compact_blank,
      name: { fr: r['route_long_name'] }.compact_blank,
      description: { fr: r['route_desc'] }.compact_blank,
      colour: r['route_color'] ? "##{r['route_color']}" : nil,
      # route_text_color
      # FIXME temp route:gpx_trace
      route: {
        gpx_trace: "#{@settings.path}/#{@destination_id&.gsub('/', '_')}-#{ref}.gpx"
      },
    }
  end

  def map_refs(feat)
    feat['properties']['stop_ids']&.[](..-2)&.split('~,')
  end
end
