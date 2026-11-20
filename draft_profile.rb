require 'uri'

module DraftProfile
  VERSION = 'http://remotestorage.io/spec/version'
  REL = 'http://tools.ietf.org/id/draft-dejong-remotestorage'
  AUTHORIZATION = 'http://tools.ietf.org/html/rfc6749#section-3.1'
  TOKEN = 'http://tools.ietf.org/html/rfc6749#section-3.2'
  PKCE = 'http://tools.ietf.org/html/rfc7636'
  RANGE = 'http://tools.ietf.org/html/rfc7233'

  def self.number(value)
    match = /\A(?:draft-dejong-remotestorage-)?([0-9]{1,2})\z/.match(value.to_s)
    return match[1].to_i if match && (3..27).cover?(match[1].to_i)
    raise ArgumentError, "Unsupported remoteStorage draft #{value.inspect} (expected 03–27)"
  end

  def self.storage_link(jrd, storage_root)
    links = jrd.fetch('links').select do |link|
      [REL, 'remotestorage'].include?(link['rel']) &&
        link['href'].to_s.chomp('/') == storage_root.chomp('/')
    end
    # Some servers publish both a current and a legacy link.
    links.find { |link| link['rel'] == REL } || links.first ||
      raise(ArgumentError, "No remoteStorage link for #{storage_root}")
  end

  def self.select_version(configured, link)
    advertised = number(link.fetch('properties').fetch(VERSION)) if link
    target = number(configured) unless configured.nil?
    if target && advertised && target != advertised
      raise ArgumentError, "Configured draft #{target} differs from advertised draft #{advertised}"
    end
    target || advertised
  end

  def self.validate_cache!(draft, headers, public_path: false)
    if draft && draft < 6
      raise ArgumentError, "Expected Expires: 0, got #{headers[:expires].inspect}" unless headers[:expires] == '0'
      return
    end
    required = ['no-cache']
    required << 'public' if public_path && draft && draft >= 26
    actual = headers[:cache_control].to_s.downcase.split(',').map(&:strip)
    if required.include?('public') && actual.include?('private')
      raise ArgumentError, 'Public Cache-Control also declares private'
    end
    missing = required - actual
    unless missing.empty?
      raise ArgumentError, "Missing Cache-Control #{missing.join(', ')} in #{headers[:cache_control].inspect}"
    end
  end

  # No extension properties means an implicit-only server, which is valid.
  def self.validate_pkce!(properties)
    return false unless [AUTHORIZATION, TOKEN, PKCE].any? { |key| properties.key?(key) }
    [AUTHORIZATION, TOKEN].each do |key|
      raise ArgumentError, "Expected an absolute endpoint URL for #{key}" unless endpoint?(properties[key])
    end
    methods = properties[PKCE]
    unless methods.is_a?(String) && methods.split(/[\s,]+/).include?('S256')
      raise ArgumentError, "Expected #{PKCE} to advertise S256"
    end
    true
  end

  def self.endpoint?(value)
    return false unless value.is_a?(String)
    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) && !uri.host.to_s.empty? && uri.fragment.nil?
  rescue URI::InvalidURIError
    false
  end
end
