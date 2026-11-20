require 'minitest/autorun'
require_relative '../draft_profile'

class DraftProfileTest < Minitest::Test
  ROOT = 'https://storage.example/alice'
  PROPS = { DraftProfile::AUTHORIZATION => 'https://login.example/authorize',
            DraftProfile::TOKEN => 'https://login.example/token',
            DraftProfile::PKCE => 'S256' }

  def link(version)
    { 'href' => ROOT, 'rel' => DraftProfile::REL,
      'properties' => { DraftProfile::VERSION => 'draft-dejong-remotestorage-%02d' % version } }
  end

  def test_version_selection
    assert_nil DraftProfile.select_version(nil, nil)
    assert_equal 3, DraftProfile.select_version('03', nil)
    assert_equal 22, DraftProfile.select_version(nil, link(22))
    assert_equal 27, DraftProfile.select_version(27, link(27))
    assert_raises(ArgumentError) { DraftProfile.select_version(26, link(27)) }
    [2, 28, 'draft-27x'].each { |v| assert_raises(ArgumentError) { DraftProfile.number(v) } }
  end

  def test_selects_the_matching_account_and_prefers_the_current_relation
    current = link(27)
    legacy = link(3).merge('rel' => 'remotestorage')
    other = current.merge('href' => ROOT + '-other')
    assert_equal current, DraftProfile.storage_link({'links' => [other, legacy, current]}, ROOT + '/')
    assert_equal legacy, DraftProfile.storage_link({'links' => [legacy]}, ROOT)
    assert_raises(ArgumentError) { DraftProfile.storage_link({'links' => [other]}, ROOT) }
  end

  def test_optional_pkce_advertisement
    DraftProfile.validate_pkce!({})
    DraftProfile.validate_pkce!(PROPS)
    DraftProfile.validate_pkce!(PROPS.merge(DraftProfile::PKCE => 'plain S256'))
    PROPS.each_key do |key|
      assert_raises(ArgumentError) { DraftProfile.validate_pkce!(PROPS.reject { |k, _| k == key }) }
    end
    [nil, ['S256'], 'plain', 'S256x'].each do |value|
      assert_raises(ArgumentError) { DraftProfile.validate_pkce!(PROPS.merge(DraftProfile::PKCE => value)) }
    end
    assert_raises(ArgumentError) { DraftProfile.validate_pkce!(PROPS.merge(DraftProfile::TOKEN => '/token')) }
  end
end
