def main(ctx):
  versions = [
    'latest',
    '7.0',
    '7.1',
    '7.2',
    '7.3',
    '7.4',
    '7.4-ubuntu20.04',
    '7.4-ubuntu22.04',
    '8.0',
    '8.1',
  ]

  arches = [
    'amd64',
    'arm64v8',
  ]

  config = {
    'version': None,
    'arch': None,
    'trigger': [],
    'repo': ctx.repo.name
  }

  stages = []

  for version in versions:
    config['version'] = version

    if config['version'] == 'latest':
      config['path'] = 'latest'
    else:
      config['path'] = 'v%s' % config['version']

    m = manifest(config)
    inner = []

    for arch in arches:
      config['arch'] = arch

      if config['version'] == 'latest':
        config['tag'] = arch
      else:
        config['tag'] = '%s-%s' % (config['version'], arch)

      if config['arch'] == 'amd64':
        config['platform'] = 'amd64'

      if config['arch'] == 'arm64v8':
        config['platform'] = 'arm64'

      config['internal'] = '%s-%s' % (ctx.build.commit, config['tag'])
      config['expected_modules'] = 'curl|mbstring|gd'
      if config['platform'] == 'amd64':
        config['expected_modules'] = config['expected_modules'] + '|oci8'

      d = docker(config)
      m['depends_on'].append(d['name'])

      inner.append(d)

    inner.append(m)
    stages.extend(inner)

  after = [
    notification(config),
  ]

  for s in stages:
    for a in after:
      a['depends_on'].append(s['name'])

  return stages + after

def docker(config):
  return {
    'kind': 'pipeline',
    'type': 'docker',
    'name': '%s-%s' % (config['arch'], config['path']),
    'platform': {
      'os': 'linux',
      'arch': config['platform'],
    },
    'steps': steps(config),
    'image_pull_secrets': [
      'registries',
    ],
    'depends_on': [],
    'trigger': {
      'ref': [
        'refs/heads/master',
        'refs/pull/**',
      ],
    },
  }

def manifest(config):
  return {
    'kind': 'pipeline',
    'type': 'docker',
    'name': 'manifest-%s' % config['path'],
    'platform': {
      'os': 'linux',
      'arch': 'amd64',
    },
    'steps': [
      {
        'name': 'manifest',
        'image': 'plugins/manifest',
        'settings': {
          'username': {
            'from_secret': 'public_username',
          },
          'password': {
            'from_secret': 'public_password',
          },
          'spec': '%s/manifest.tmpl' % config['path'],
          'ignore_missing': 'true',
        },
      },
    ],
    'depends_on': [],
    'trigger': {
      'ref': [
        'refs/heads/master',
        'refs/tags/**',
      ],
    },
  }

def notification(config):
  steps = [{
    'name': 'notify',
    'image': 'plugins/slack',
    'settings': {
      'webhook': {
        'from_secret': 'private_rocketchat',
      },
      'channel': 'builds',
    },
    'when': {
      'status': [
        'success',
        'failure',
      ],
    },
  }]

  downstream = [{
    'name': 'downstream',
    'image': 'plugins/downstream',
    'settings': {
      'token': {
        'from_secret': 'drone_token',
      },
      'server': 'https://drone.owncloud.com',
      'repositories': config['trigger'],
    },
    'when': {
      'status': [
        'success',
      ],
    },
  }]

  if config['trigger']:
    steps = downstream + steps

  return {
    'kind': 'pipeline',
    'type': 'docker',
    'name': 'notification',
    'platform': {
      'os': 'linux',
      'arch': 'amd64',
    },
    'clone': {
      'disable': True,
    },
    'steps': steps,
    'depends_on': [],
    'trigger': {
      'ref': [
        'refs/heads/master',
        'refs/tags/**',
      ],
      'status': [
        'success',
        'failure',
      ],
    },
  }

def prepublish(config):
  return [{
    'name': 'prepublish',
    'image': 'plugins/docker',
    'settings': {
      'username': {
        'from_secret': 'internal_username',
      },
      'password': {
        'from_secret': 'internal_password',
      },
      'tags': config['internal'],
      'dockerfile': '%s/Dockerfile.%s' % (config['path'], config['arch']),
      'repo': 'registry.drone.owncloud.com/owncloudci/%s' % config['repo'],
      'registry': 'registry.drone.owncloud.com',
      'context': config['path'],
      'purge': False,
    }
  }]

def sleep(config):
  return [{
    'name': 'sleep',
    'image': 'owncloudci/alpine:latest',
    'environment': {
      'DOCKER_USER': {
        'from_secret': 'internal_username',
      },
      'DOCKER_PASSWORD': {
        'from_secret': 'internal_password',
      },
    },
    'commands': [
      "retry -- 'reg digest --username $DOCKER_USER --password $DOCKER_PASSWORD registry.drone.owncloud.com/owncloudci/%s:%s'" % (config['repo'], config['internal']),
    ],
  }]

def assert(config):
  return [{
    'name': 'assert',
    'image': 'registry.drone.owncloud.com/owncloudci/%s:%s' % (config['repo'], config['internal']),
    'detach': True,
    'commands': [
      'php -m | grep -E "%s"' % config['expected_modules']
    ],
  }]

def server(config):
  return [{
    'name': 'server',
    'image': 'registry.drone.owncloud.com/owncloudci/%s:%s' % (config['repo'], config['internal']),
    'detach': True,
    'commands': [
      'apachectl -DFOREGROUND',
    ],
  }]

def wait(config):
  return [{
    'name': 'wait',
    'image': 'owncloud/ubuntu:latest',
    'commands': [
      'wait-for-it -t 600 server:80',
    ],
  }]

def tests(config):
  return [{
    'name': 'test',
    'image': 'owncloud/ubuntu:latest',
    'commands': [
      'curl -sSf http://server:80/',
    ],
  }]

def publish(config):
  return [{
    'name': 'publish',
    'image': 'plugins/docker',
    'settings': {
      'username': {
        'from_secret': 'public_username',
      },
      'password': {
        'from_secret': 'public_password',
      },
      'tags': config['tag'],
      'dockerfile': '%s/Dockerfile.%s' % (config['path'], config['arch']),
      'repo': 'owncloudci/%s' % config['repo'],
      'context': config['path'],
      'cache_from': 'registry.drone.owncloud.com/owncloudci/%s:%s' % (config['repo'], config['internal']),
      'pull_image': False,
    },
    'when': {
      'ref': [
        'refs/heads/master',
        'refs/tags/**',
      ],
    },
  }]

def cleanup(config):
  return [{
    'name': 'cleanup',
    'image': 'owncloudci/alpine:latest',
    'failure': 'ignore',
    'environment': {
      'DOCKER_USER': {
        'from_secret': 'internal_username',
      },
      'DOCKER_PASSWORD': {
        'from_secret': 'internal_password',
      },
    },
    'commands': [
      'reg rm --username $DOCKER_USER --password $DOCKER_PASSWORD registry.drone.owncloud.com/owncloudci/%s:%s' % (config['repo'], config['internal']),
    ],
    'when': {
      'status': [
        'success',
        'failure',
      ],
    },
  }]

def steps(config):
  return prepublish(config) + sleep(config) + assert(config) + server(config) + wait(config) + tests(config) + publish(config)
