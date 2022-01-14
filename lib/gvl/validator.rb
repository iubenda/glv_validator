# frozen_string_literal: true

require 'faraday'
require 'json'

class Validator
  attr_reader :version, :url, :vendorlist, :success, :errors, :last_check

  LATEST_URL  = 'https://vendor-list.consensu.org/v2/vendor-list.json'
  ARCHIVE_URL = 'https://vendor-list.consensu.org/v2/archives/vendor-list-v%<version>d.json'

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
  end

  def validate_disclosures(disclosures)
    @errors = disclosures.each_with_object([]) do |(_k, v), memo|
      fetch_disclosure(v['deviceStorageDisclosureUrl'])
    rescue Faraday::Error, JSON::ParserError => e
      memo << { 'vendor' => v, 'error' => e.message }
      next
    end

    @success = true if @success.nil?
    @last_check = Time.now
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
