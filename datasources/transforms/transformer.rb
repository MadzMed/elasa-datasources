# frozen_string_literal: true
# typed: true

class Transformer
  extend T::Sig
  extend T::Helpers
  abstract!

  def initialize(settings)
    @settings = settings
    @has_schema = false
    @has_i18n = false
    @has_osm_tags = false
    @count_input_row = 0
    @count_output_row = 0
  end

  def process_schema(data)
    data
  end

  def process_osm_tags(data)
    data
  end

  def process(row)
    type, data = row
    case type
    when :schema
      d = process_schema(data)
      if d.present?
        @has_schema = data[:schema].present?
        @has_i18n = data[:i18n].present?
        [type, d]
      end
    when :osm_tags
      d = process_osm_tags(data)
      if d&.dig(:data).present?
        @has_osm_tags = true
        [type, d]
      end
    when :data
      @count_input_row += 1
      begin
        d = process_data(data)
        if !d.nil?
          @count_output_row += 1
          [type, d]
        end
      rescue StandardError => e
        logger.debug("#{e}\n\n")
        nil
      end
    else raise "Not support stream item #{type}"
    end
  end

  def close_schema; end

  def close_osm_tags; end

  def close_data; end

  def close
    close_schema { |data|
      if data.present?
        @has_schema = data[:schema].present?
        @has_i18n = data[:i18n].present?
        yield [:schema, data]
      end
    }

    close_osm_tags { |data|
      if data&.dig(:data).present?
        @has_osm_tags = true
        yield [:osm_tags, data]
      end
    }

    close_data { |data|
      if !data.nil?
        @count_output_row += 1
        yield [:data, data]
      end
    }

    count = @count_output_row == @count_input_row ? @count_input_row.to_s : "#{@count_input_row} -> #{@count_output_row}"
    log = "    ~ #{self.class.name}: #{count}"
    log += ' +schema' if @has_schema
    log += ' +i18n' if @has_i18n
    log += ' +osm_tags' if @has_osm_tags
    logger.info(log)
  end
end
