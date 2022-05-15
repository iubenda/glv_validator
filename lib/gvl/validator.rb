# frozen_string_literal: true

require 'faraday'
require 'json'

class Validator
  attr_reader :version, :url, :vendorlist, :success, :errors, :last_check

  LATEST_URL  = 'https://vendor-list.consensu.org/v2/vendor-list.json'
  ARCHIVE_URL = 'https://vendor-list.consensu.org/v2/archives/vendor-list-v%<version>d.json'

  REQUIRED_COOKIE_KEYS = %w[identifier type maxAgeSeconds].freeze
  COOKIE_SCHEMA = {
    identifier:    [String],
    type:          [String],
    maxAgeSeconds: [Integer, NilClass],
    domain:        [String, NilClass]
  }.freeze

  def initialize(version = nil)
    @version = version
  end

  def validate!
    set_url
    fetch_vendorlist
    validate_disclosures(disclosures)

    self
  end

  def set_url
    @url = if version.nil?
             LATEST_URL
           else
             format(ARCHIVE_URL, version: version)
           end
  end

  def fetch_vendorlist
    response = Faraday.get(url)
    @vendorlist = JSON.parse(response.body)
    @version = vendorlist['vendorListVersion']
  rescue Faraday::Error, JSON::ParserError
    @success = false
    @vendorlist = { 'vendors' => {} }
  end

  def disclosures
    vendors = vendorlist['vendors']
    vendors.reject { |_k, v| v['deviceStorageDisclosureUrl'].nil? }
  end

  def fetch_disclosure(disclosure)
    response = Faraday.get(disclosure)
    unless response.success?
      raise Faraday::Error, "Connection failed: #{response.status} #{response.reason_phrase}"
    end

    JSON.parse(response.body)
  rescue JSON::ParserError
    raise JSON::ParserError, 'Invalid JSON'
  end

  def validate_disclosures(disclosures)
    @errors = disclosures.each_with_object([]) do |(_k, v), memo|
      list = fetch_disclosure(v['deviceStorageDisclosureUrl'])
      raise JSON::ParserError, 'Invalid cookie schema' unless list.is_a?(Hash) && list.key?('disclosures')

      cookies = list['disclosures']
      raise JSON::ParserError, 'Invalid cookie schema' if cookies.nil?

      cookies.each do |cookie|
        unless valid_cookie?(cookie)
          raise JSON::ParserError, 'Invalid cookie schema'
        end
      end
    rescue Faraday::Error, JSON::ParserError => e
      memo << { 'vendor' => v, 'error' => e.message }
      next
    rescue URI::InvalidURIError => e
      memo << { 'vendor' => v, 'error' => 'Invalid URL' }
      next
    end

    @success = true if @success.nil?
    @last_check = Time.now
  end

  def valid_cookie?(cookie)
    return false unless (REQUIRED_COOKIE_KEYS - cookie.keys).empty?

    COOKIE_SCHEMA.all? { |key, types| types.include?(cookie[key.to_s].class) }
  end

  def to_h
    {
      'version'    => version,
      'url'        => url,
      'success'    => success,
      'errors'     => errors,
      'last_check' => last_check
    }
  end

  def to_json(*args)
    JSON.generate(to_h, *args)
  end
end
