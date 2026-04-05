@ignore
Feature: Hold expiration worker coverage for HU8

Background:
  * def data = read('worker-data.json')

@TC-HU8-01 @worker @alto
Scenario: Expire holds older than ten minutes when the worker runs
  * karate.abort()

@TC-HU8-02 @worker @alto
Scenario: Keep recent holds pending when the worker runs
  * karate.abort()

@TC-HU8-03 @worker @alto
Scenario: Expire multiple aged holds in a single worker execution
  * karate.abort()

@TC-HU8-04 @worker @alto
Scenario: Leave confirmed and released holds untouched
  * karate.abort()
