# Wachtwoord

Provides a seamless way to ensure consistent versions of secrets across a fleet of dynos. Secrets themselves are stored in AWS [Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html). Secret version management is accomplished by setting incrementing [version stage](https://docs.aws.amazon.com/secretsmanager/latest/userguide/whats-in-a-secret.html#term_version) labels on secret versions as secret values are updated. Uses environment variables as input in order to determine which version of a secret is desired. Exposes the secret value for the desired version as an environment variable to your application.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add wachtwoord

## Usage

In all examples `name_of_secret` is a snake-cased and will ultimately be the environment variable name used to provide the secret value to your application. Wachtwoord is not meant to be used in dev/test environments as we don't want to require AWS access for non-production environments. All `secret` rake tasks are expected to be run via `heroku rake ...` in the desired environment.

For example, with this configuration:

- `secrets_namespace` set to `cleo-production-private`
- Name of secret is: `something_private`
- You've run `rake secret:add\['<something_private>'\]` twice; there's now two versions of the secret, with the following secret values:
  1. `blah1`
  2. `blah2`

The secret will be named `cleo-production-private/something_private` in AWS Secret Manager.

ENV you need to add to your configuration if you want the _first_ version of the secret:
`SECRET_VERSION_ENV_SOMETHING_PRIVATE=1`

ENV that gets set via Wachtwoord:
`SOMETHING_PRIVATE=blah1`

ENV you need to add to your configuration if you want the _second_ version of the secret:
`SECRET_VERSION_ENV_SOMETHING_PRIVATE=2`

ENV that gets set via Wachtwoord:
`SOMETHING_PRIVATE=blah2`

### Configuration

#### Secrets namespace

The secrets namespace is what's used to let you store the same secret name, but with different values depending on the environment/application. Secrets are stored in Secrets Manager in the format: `<secrets_namespace>/<name_of_secret>`.

Setting the secrets namespace:

```ruby
Wachtwoord.configure do |config|
  config.secrets_namespace = 'meetcleo_production'
end
```

Or, you can set the `WACHTWOORD_SECRETS_NAMESPACE` env.

#### Secret name tokens

Secret name tokens are what's used to pattern match for detecting potential plain-text secrets in your `.env` files. The configuration comes with a default list of tokens, which you can customise as needed.

Adding a secret name token:

```ruby
Wachtwoord.configure do |config|
  config.secret_name_tokens << 'password'
end
```

Or, you can set the `WACHTWOORD_SECRET_NAME_TOKENS` env with comma-separated values.

#### Allowed config names

Related to the above, you can also provide an allow-list of ENV names you want to allow-list, so that they are not counted as plain-text secrets in your `.env` files.

Adding an allowed config name:

```ruby
Wachtwoord.configure do |config|
  config.allowed_config_names << 'SECRET_AUTH_TOKEN_JK'
end
```

Or, you can set the `WACHTWOORD_ALLOWED_CONFIG_NAMES` env with comma-separated values.

#### AWS user

You'll need an AWS user or role with the following access to secrets manager:

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "VisualEditor0",
			"Effect": "Allow",
			"Action": [
				"secretsmanager:GetResourcePolicy",
				"secretsmanager:GetSecretValue",
				"secretsmanager:DescribeSecret",
				"secretsmanager:PutSecretValue",
				"secretsmanager:CreateSecret",
				"secretsmanager:UpdateSecretVersionStage",
				"secretsmanager:ListSecretVersionIds"
			],
			"Resource": "arn:aws:secretsmanager:us-east-1:878877078763:secret:<secrets_namespace>/*"
		},
		{
			"Sid": "VisualEditor1",
			"Effect": "Allow",
			"Action": [
				"secretsmanager:GetRandomPassword",
				"secretsmanager:ListSecrets",
				"secretsmanager:BatchGetSecretValue"
			],
			"Resource": "*"
		}
	]
}
```

### Detecting plain-text secrets in `.env` files:

    $ bundle exec wachtwoord .env.staging .env.production

```
potential secret in .env.production on line 72
potential secret in .env.production on line 74
potential secret in .env.production on line 111
```

Useful for pre-commit hooks, you can pass a list of filenames and it will check those files for any lines that look like they might contain plain-text secrets. It fails with a non-zero exit code and prints the offending line numbers. See also `secret_name_tokens` and `allowed_config_names` configurations.

### Adding a new secret:

    $ bundle exec rake secret:add\['<name_of_secret>'\]

```
Secret called `<name_of_secret>` does not exist, would you like to create it? (y/n)>
y
Enter the secret value>
<your_big_secret>
Add an optional description>
<something_to_describe_what_your_secret_is_used_for>
Add the following to your .env.x file to use this version: SECRET_VERSION_ENV_<name_of_secret>=1
```

By setting this in your application's ENV `SECRET_VERSION_ENV_<name_of_secret>=1` you're telling Wachtwoord you wish to receive this secret's value at the first version.

### Changing the value of a secret:

    $ bundle exec rake secret:add\['<name_of_secret>'\]

```
Secret called `<name_of_secret>` already exists, would you like to add a new version? (y/n)>
y
Enter the secret value>
<your_big_secret>
Add the following to your .env.x file to use this version: SECRET_VERSION_ENV_<name_of_secret>=2
```

By setting this in your application's ENV `SECRET_VERSION_ENV_<name_of_secret>=2` you're telling Wachtwoord you wish to receive this secret's value at the second [updated] version.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. Run `bundle exec rake` to run tests, RuboCop checks, and Sorbet type checks.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/meetcleo/wachtwoord.
