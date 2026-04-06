@ignore
Feature: Defer external OAuth flow until the contract is available

Scenario: Skip until the identity provider contract is available
  * karate.abort()
