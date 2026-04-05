Feature: Resolve authentication context

Scenario: Build request headers from runtime configuration
  * def token = authToken
  * def headers = token ? { Authorization: 'Bearer ' + token } : {}
