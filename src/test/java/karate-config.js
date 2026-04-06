function fn() {
  var env = karate.env || 'local';
  var timeout = karate.properties['karate.timeout'] ? parseInt(karate.properties['karate.timeout'], 10) : 30000;
  var baseUrlOverride = karate.properties['base.url'] || karate.properties['baseUrl'] || '';
  var baseUrlMap = {
    local: 'http://localhost:5173/api/v1',
    dev: 'http://localhost:5173/api/v1',
    ci: 'http://localhost:3100/api/v1',
    staging: 'https://api.staging.example.com',
    prod: 'https://api.example.com'
  };

  var config = {
    env: env,
    baseUrl: baseUrlOverride || baseUrlMap[env] || baseUrlMap.local,
    authUrl: karate.properties['auth.url'] || 'https://auth.dev.example.com',
    timeout: timeout,
    authToken: karate.properties['auth.token'] || '',
    authEnforced: karate.properties['auth.enforced'] === 'true',
    workerEnabled: karate.properties['worker.enabled'] === 'true',
    holdTtlSeconds: 600,
    defaultHeaders: {
      Accept: 'application/json',
      'Content-Type': 'application/json'
    }
  };

  if (env === 'prod') {
    config.timeout = 60000;
  }

  karate.configure('connectTimeout', config.timeout);
  karate.configure('readTimeout', config.timeout);

  return config;
}
