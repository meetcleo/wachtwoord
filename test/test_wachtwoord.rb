# typed: false
# frozen_string_literal: true

require 'test_helper'

class TestWachtwoord < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil described_class::VERSION
  end

  def test_that_it_has_a_configuration
    refute_nil described_class.configuration
  end

  def test_load_secrets_into_env
    set_envs
    expect_fetch

    assert_raises(Wachtwoord::ChangingExistingEnvError) do
      described_class.load_secrets_into_env
    end

    assert_equal('blah', ENV.fetch('BLAH1', nil)) # Sets the new ENV
    assert_equal('already set', ENV.fetch('BLAH2', nil)) # Does not overwrite existing ENV
  ensure
    unset_envs
  end

  def test_load_secrets_into_env_preserve_existing
    set_envs
    expect_fetch
    described_class.load_secrets_into_env(clash_behaviour: :preserve_env)

    assert_equal('blah', ENV.fetch('BLAH1', nil)) # Sets the new ENV
    assert_equal('already set', ENV.fetch('BLAH2', nil)) # Does not overwrite existing ENV
  ensure
    unset_envs
  end

  def test_load_secrets_into_env_preserve_existing_forced_overwrite
    set_envs
    expect_fetch
    described_class.configuration.forced_overwrite_config_names = ['BLAH2']
    described_class.load_secrets_into_env(clash_behaviour: :preserve_env)

    assert_equal('blah', ENV.fetch('BLAH1', nil)) # Sets the new ENV
    assert_equal('unexpected', ENV.fetch('BLAH2', nil)) # BLAH2 is in the forced overwrite list, so overwrites still
  ensure
    unset_envs
  end

  def test_load_secrets_into_env_overwrite_existing
    set_envs
    expect_fetch
    described_class.load_secrets_into_env(clash_behaviour: :overwrite_env)

    assert_equal('blah', ENV.fetch('BLAH1', nil)) # Sets the new ENV
    assert_equal('unexpected', ENV.fetch('BLAH2', nil)) # Overwrites existing ENV
  ensure
    unset_envs
  end

  def test_load_secrets_into_env_not_found_raise
    set_envs
    expect_fetch(errors: [{ error_code: Wachtwoord::Fetch::RESOURCE_NOT_FOUND_ERROR_CLASS_NAME }])

    assert_raises(Wachtwoord::Fetch::MissingSecretsError) do
      described_class.load_secrets_into_env
    end

    assert_nil(ENV.fetch('BLAH1', nil))
    assert_equal('already set', ENV.fetch('BLAH2', nil)) # Does not overwrite existing ENV
  ensure
    unset_envs
  end

  def test_load_secrets_into_env_not_found_not_raise
    Wachtwoord.configure do |config|
      config.raise_if_secret_not_found = false
    end
    set_envs
    expect_fetch(errors: [{ error_code: Wachtwoord::Fetch::RESOURCE_NOT_FOUND_ERROR_CLASS_NAME }])

    assert_raises(Wachtwoord::ChangingExistingEnvError) do
      described_class.load_secrets_into_env
    end

    assert_equal('blah', ENV.fetch('BLAH1', nil)) # Sets the new ENV
    assert_equal('already set', ENV.fetch('BLAH2', nil)) # Does not overwrite existing ENV
  ensure
    unset_envs
  end

  private

  def set_envs
    assert_nil ENV.fetch('BLAH1', nil)
    ENV['BLAH2'] = 'already set'
    ENV['SECRET_VERSION_ENV_BLAH1'] = '1'
    ENV['SECRET_VERSION_ENV_BLAH2'] = '1'
  end

  def unset_envs
    ENV['BLAH1'] = nil
    ENV['SECRET_VERSION_ENV_BLAH1'] = nil
    ENV['BLAH2'] = nil
    ENV['SECRET_VERSION_ENV_BLAH2'] = nil
  end

  def expect_fetch(errors: [])
    client = mock(:client)
    Wachtwoord.expects(:client).returns(client)
    client.expects(:batch_get_secret_value)
          .with({ secret_id_list: ['/blah1', '/blah2'] })
          .returns({
                     errors:,
                     next_token: nil,
                     secret_values: [
                       {
                         arn: '&region-arn;&asm-service-name;:us-west-2:&ExampleAccountId;:secret:MySecret1-a1b2c3',
                         created_date: Time.parse('2024-11-15T00:05:07Z'),
                         name: '/blah1',
                         secret_string: '{"value":"blah"}',
                         version_id: 'a1b2c3d4-5678-90ab-cdef-EXAMPLEaaaaa',
                         version_stages: %w[
                           AWSCURRENT
                           CLEO-001
                         ]
                       },
                       {
                         arn: '&region-arn;&asm-service-name;:us-west-2:&ExampleAccountId;:secret:MySecret1-a1b2c3',
                         created_date: Time.parse('2024-11-15T00:05:07Z'),
                         name: '/blah2',
                         secret_string: '{"value":"unexpected"}',
                         version_id: 'a1b2c3d4-5678-90ab-cdef-EXAMPLEaaaaa',
                         version_stages: %w[
                           AWSCURRENT
                           CLEO-001
                         ]
                       }
                     ]
                   })
  end
end
