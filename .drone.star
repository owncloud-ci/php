def main(ctx):
  versions = [
    'latest',
    '5.6',
    '7.0',
    '7.1',
    '7.2',
    '7.3',
    '7.4',
  ]

  arches = [
    'amd64',
    'arm32v7',
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

      if config['arch'] == 'arm32v7':
        config['platform'] = 'arm'

      config['internal'] = '%s-%s' % (ctx.build.commit, config['tag'])

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
    'volumes': volumes(config),
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

def microbadger(config):
  return {
    'kind': 'pipeline',
    'type': 'docker',
    'name': 'microbadger',
    'platform': {
      'os': 'linux',
      'arch': 'amd64',
    },
    'clone': {
      'disable': True,
    },
    'steps': [
      {
        'name': 'notify',
        'image': 'plugins/webhook',
        'failure': 'ignore',
        'settings': {
          'urls': {
            'from_secret': 'microbadger_url',
          },
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
    },
    'volumes': [
      {
        'name': 'docker',
        'path': '/var/lib/docker',
      },
    ],
  }]

def sleep(config):
  return [{
    'name': 'sleep',
    'image': 'toolhippie/reg:latest',
    'environment': {
      'DOCKER_USER': {
        'from_secret': 'internal_username',
      },
      'DOCKER_PASSWORD': {
        'from_secret': 'internal_password',
      },
    },
    'commands': [
      'retry -- reg digest --username $DOCKER_USER --password $DOCKER_PASSWORD registry.drone.owncloud.com/owncloudci/%s:%s' % (config['repo'], config['internal']),
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
      'pull_image': False,
    },
    'volumes': [
      {
        'name': 'docker',
        'path': '/var/lib/docker',
      },
    ],
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
    'image': 'toolhippie/reg:latest',
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

def volumes(config):
  return [
    {
      'name': 'docker',
      'temp': {},
    },
  ]

def steps(config):
  return prepublish(config) + server(config) + wait(config) + tests(config) + publish(config)
