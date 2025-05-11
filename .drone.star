DRONE_DOCKER_BUILDX_IMAGE = "docker.io/owncloudci/drone-docker-buildx:4"

def main(ctx):
    versions = [
        {
            "value": "7.4",
        },
        {
            "value": "7.4-ubuntu24.04",
        },
        {
            "value": "8.0",
        },
        {
            "value": "8.1",
        },
        {
            "value": "8.2",
        },
        {
            "value": "8.3",
        },
    ]

    config = {
        "version": None,
        "description": "ownCloud PHP base image for use in CI",
        "arch": None,
        "repo": ctx.repo.name,
    }

    stages = []
    shell = []
    linter = lint(config)

    for version in versions:
        config["version"] = version
        config["version"]["path"] = "v%s" % config["version"]["value"]

        shell.extend(shellcheck(config))
        inner = []
        config["internal"] = "%s-%s-%s" % (ctx.build.commit, "${DRONE_BUILD_NUMBER}", config["version"]["path"])
        config["version"]["tags"] = version.get("tags", [])
        config["version"]["tags"].append(config["version"]["value"])
        config["expected_modules"] = "curl|mbstring|gd|oci8"

        d = docker(config)
        d["depends_on"].append(linter["name"])
        inner.append(d)

        stages.extend(inner)

    linter["steps"].extend(shell)

    after = [
        rocketchat(config),
    ]

    for s in stages:
        for a in after:
            a["depends_on"].append(s["name"])

    return [linter] + stages + after

def docker(config):
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "%s" % (config["version"]["path"]),
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "steps": steps(config),
        "volumes": volumes(config),
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/pull/**",
            ],
        },
    }

def rocketchat(config):
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "rocketchat",
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "clone": {
            "disable": True,
        },
        "steps": [
            {
                "name": "notify",
                "image": "docker.io/plugins/slack",
                "failure": "ignore",
                "settings": {
                    "webhook": {
                        "from_secret": "rocketchat_talk_webhook",
                    },
                    "channel": "builds",
                },
            },
        ],
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/tags/**",
            ],
            "status": [
                "changed",
                "failure",
            ],
        },
    }

def prepublish(config):
    return [
        {
            "name": "prepublish",
            "image": DRONE_DOCKER_BUILDX_IMAGE,
            "settings": {
                "username": {
                    "from_secret": "internal_username",
                },
                "password": {
                    "from_secret": "internal_password",
                },
                "tags": config["internal"],
                "secrets": ["id=mirror-auth\\\\,src=/drone/src/mirror-auth", "id=mirror-url\\\\,src=/drone/src/mirror-url"],
                "dockerfile": "%s/Dockerfile.multiarch" % (config["version"]["path"]),
                "repo": "registry.drone.owncloud.com/owncloudci/%s" % config["repo"],
                "registry": "registry.drone.owncloud.com",
                "context": config["version"]["path"],
                "purge": False,
            },
            "environment": {
                "BUILDKIT_NO_CLIENT_TOKEN": True,
            },
        },
    ]

def sleep(config):
    return [
        {
            "name": "sleep",
            "image": "docker.io/owncloudci/alpine",
            "environment": {
                "DOCKER_USER": {
                    "from_secret": "internal_username",
                },
                "DOCKER_PASSWORD": {
                    "from_secret": "internal_password",
                },
            },
            "commands": [
                "regctl registry login registry.drone.owncloud.com --user $DOCKER_USER --pass $DOCKER_PASSWORD",
                "retry -- 'regctl image digest registry.drone.owncloud.com/owncloudci/%s:%s'" % (config["repo"], config["internal"]),
            ],
        },
    ]

# container vulnerability scanning, see: https://github.com/aquasecurity/trivy
def trivy(config):
    return [
        {
            "name": "trivy-presets",
            "image": "docker.io/owncloudci/alpine",
            "commands": [
                'retry -t 3 -s 5 -- "curl -sSfL https://github.com/owncloud-docker/trivy-presets/archive/refs/heads/main.tar.gz | tar xz --strip-components=2 trivy-presets-main/base/"',
            ],
        },
        {
            "name": "trivy-scan",
            "image": "ghcr.io/aquasecurity/trivy",
            "environment": {
                "TRIVY_AUTH_URL": "https://registry.drone.owncloud.com",
                "TRIVY_USERNAME": {
                    "from_secret": "internal_username",
                },
                "TRIVY_PASSWORD": {
                    "from_secret": "internal_password",
                },
                "TRIVY_NO_PROGRESS": True,
                "TRIVY_IGNORE_UNFIXED": True,
                "TRIVY_TIMEOUT": "5m",
                "TRIVY_EXIT_CODE": "1",
                "TRIVY_SEVERITY": "HIGH,CRITICAL",
                "TRIVY_SKIP_FILES": "/usr/bin/gomplate",
            },
            "commands": [
                "trivy -v",
                "trivy image registry.drone.owncloud.com/owncloudci/%s:%s" % (config["repo"], config["internal"]),
            ],
        },
    ]

def publish(config):
    return [
        {
            "name": "publish",
            "image": DRONE_DOCKER_BUILDX_IMAGE,
            "settings": {
                "username": {
                    "from_secret": "public_username",
                },
                "password": {
                    "from_secret": "public_password",
                },
                "platforms": [
                    "linux/amd64",
                    "linux/arm64",
                ],
                "tags": config["version"]["tags"],
                "secrets": ["id=mirror-auth\\\\,src=/drone/src/mirror-auth", "id=mirror-url\\\\,src=/drone/src/mirror-url"],
                "dockerfile": "%s/Dockerfile.multiarch" % (config["version"]["path"]),
                "repo": "owncloudci/%s" % config["repo"],
                "context": config["version"]["path"],
                "pull_image": False,
            },
            "when": {
                "ref": [
                    "refs/heads/master",
                ],
            },
        },
    ]

def setup(config):
    return [
        {
            "name": "setup",
            "image": "docker.io/owncloudci/alpine",
            "failure": "ignore",
            "environment": {
                "DEB_MIRROR_URL": {
                    "from_secret": "DEB_MIRROR_URL",
                },
                "DEB_MIRROR_LOGIN": {
                    "from_secret": "DEB_MIRROR_LOGIN",
                },
                "DEB_MIRROR_PWD": {
                    "from_secret": "DEB_MIRROR_PWD",
                },
            },
            "commands": [
                'echo "machine $DEB_MIRROR_URL login $DEB_MIRROR_LOGIN password $DEB_MIRROR_PWD" > mirror-auth',
                'echo "$DEB_MIRROR_URL" > mirror-url',
            ],
        },
    ]

def cleanup(config):
    return [
        {
            "name": "cleanup",
            "image": "docker.io/owncloudci/alpine",
            "failure": "ignore",
            "environment": {
                "DOCKER_USER": {
                    "from_secret": "internal_username",
                },
                "DOCKER_PASSWORD": {
                    "from_secret": "internal_password",
                },
            },
            "commands": [
                "rm -f mirror-auth",
                "rm -f mirror-url",
                "regctl registry login registry.drone.owncloud.com --user $DOCKER_USER --pass $DOCKER_PASSWORD",
                "regctl tag rm registry.drone.owncloud.com/owncloudci/%s:%s" % (config["repo"], config["internal"]),
            ],
            "when": {
                "status": [
                    "success",
                    "failure",
                ],
            },
        },
    ]

def volumes(config):
    return [
        {
            "name": "docker",
            "temp": {},
        },
    ]

def lint(config):
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "lint",
        "steps": [
            {
                "name": "starlark-format",
                "image": "docker.io/owncloudci/bazel-buildifier",
                "commands": [
                    "buildifier -d -diff_command='diff -u' .drone.star",
                ],
            },
            {
                "name": "editorconfig-format",
                "image": "docker.io/mstruebing/editorconfig-checker",
            },
        ],
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/pull/**",
            ],
        },
    }

def shellcheck(config):
    return [
        {
            "name": "shellcheck-%s" % (config["version"]["path"]),
            "image": "docker.io/koalaman/shellcheck-alpine:stable",
            "commands": [
                "grep -ErlI '^#!(.*/|.*env +)(sh|bash|ksh)' %s/overlay/ | xargs -r shellcheck" % (config["version"]["path"]),
            ],
        },
    ]

def assert(config):
    return [{
        "name": "assert",
        "image": "registry.drone.owncloud.com/owncloudci/%s:%s" % (config["repo"], config["internal"]),
        "detach": True,
        "commands": [
            'php -m | grep -E "%s"' % config["expected_modules"],
        ],
    }]

def server(config):
    return [{
        "name": "server",
        "image": "registry.drone.owncloud.com/owncloudci/%s:%s" % (config["repo"], config["internal"]),
        "detach": True,
        "commands": [
            "apachectl -DFOREGROUND",
        ],
    }]

def wait(config):
    return [{
        "name": "wait",
        "image": "owncloud/ubuntu",
        "commands": [
            "wait-for-it -t 600 server:80",
        ],
    }]

def tests(config):
    return [{
        "name": "test",
        "image": "owncloud/ubuntu",
        "commands": [
            "curl -sSf http://server:80/",
        ],
    }]

def steps(config):
    return setup(config) + prepublish(config) + sleep(config) + trivy(config) + assert(config) + server(config) + wait(config) + tests(config) + publish(config) + cleanup(config)
