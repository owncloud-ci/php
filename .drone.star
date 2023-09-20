def main(ctx):
    versions = [
        "7.4",
        "7.4-ubuntu20.04",
        "7.4-ubuntu22.04",
        "8.0",
        "8.1",
        "8.2",
    ]

    arches = [
        "amd64",
        "arm64v8",
    ]

    config = {
        "version": None,
        "arch": None,
        "repo": ctx.repo.name,
    }

    stages = []

    for version in versions:
        config["version"] = version

        config["path"] = "v%s" % config["version"]

        m = manifest(config)
        inner = []

        for arch in arches:
            config["arch"] = arch

            config["tag"] = "%s-%s" % (config["version"], arch)

            if config["arch"] == "amd64":
                config["platform"] = "amd64"

            if config["arch"] == "arm64v8":
                config["platform"] = "arm64"

            config["internal"] = "%s-%s" % (ctx.build.commit, config["tag"])
            config["expected_modules"] = "curl|mbstring|gd"
            if config["platform"] == "amd64":
                config["expected_modules"] = config["expected_modules"] + "|oci8"

            d = docker(config)
            m["depends_on"].append(d["name"])

            inner.append(d)

        inner.append(m)
        stages.extend(inner)

    after = [
        notification(config),
    ]

    for s in stages:
        for a in after:
            a["depends_on"].append(s["name"])

    return [lint()] + stages + after

def docker(config):
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "%s-%s" % (config["arch"], config["path"]),
        "platform": {
            "os": "linux",
            "arch": config["platform"],
        },
        "steps": steps(config),
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/pull/**",
            ],
        },
    }

def manifest(config):
    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "manifest-%s" % config["path"],
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "steps": [
            {
                "name": "manifest",
                "image": "plugins/manifest",
                "settings": {
                    "username": {
                        "from_secret": "public_username",
                    },
                    "password": {
                        "from_secret": "public_password",
                    },
                    "spec": "%s/manifest.tmpl" % config["path"],
                    "ignore_missing": "true",
                },
            },
        ],
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/tags/**",
            ],
        },
    }

def notification(config):
    steps = [{
        "name": "notify",
        "image": "plugins/slack",
        "settings": {
            "webhook": {
                "from_secret": "rocketchat_chat_webhook",
            },
            "channel": "builds",
        },
        "when": {
            "status": [
                "success",
                "failure",
            ],
        },
    }]

    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "notification",
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "clone": {
            "disable": True,
        },
        "steps": steps,
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/tags/**",
            ],
            "status": [
                "success",
                "failure",
            ],
        },
    }

def prepublish(config):
    return [{
        "name": "prepublish",
        "image": "plugins/docker",
        "settings": {
            "username": {
                "from_secret": "internal_username",
            },
            "password": {
                "from_secret": "internal_password",
            },
            "tags": config["internal"],
            "dockerfile": "%s/Dockerfile.%s" % (config["path"], config["arch"]),
            "repo": "registry.drone.owncloud.com/owncloudci/%s" % config["repo"],
            "registry": "registry.drone.owncloud.com",
            "context": config["path"],
            "purge": False,
        },
    }]

def sleep(config):
    return [{
        "name": "sleep",
        "image": "owncloudci/alpine",
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
    }]

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

def publish(config):
    return [{
        "name": "publish",
        "image": "plugins/docker",
        "settings": {
            "username": {
                "from_secret": "public_username",
            },
            "password": {
                "from_secret": "public_password",
            },
            "tags": config["tag"],
            "dockerfile": "%s/Dockerfile.%s" % (config["path"], config["arch"]),
            "repo": "owncloudci/%s" % config["repo"],
            "context": config["path"],
            "cache_from": "registry.drone.owncloud.com/owncloudci/%s:%s" % (config["repo"], config["internal"]),
            "pull_image": False,
        },
        "when": {
            "ref": [
                "refs/heads/master",
                "refs/tags/**",
            ],
        },
    }]

def cleanup(config):
    return [{
        "name": "cleanup",
        "image": "owncloudci/alpine",
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
            "regctl registry login registry.drone.owncloud.com --user $DOCKER_USER --pass $DOCKER_PASSWORD",
            "regctl tag rm registry.drone.owncloud.com/owncloudci/%s:%s" % (config["repo"], config["internal"]),
        ],
        "when": {
            "status": [
                "success",
                "failure",
            ],
        },
    }]

def lint():
    lint = {
        "kind": "pipeline",
        "type": "docker",
        "name": "lint",
        "steps": [
            {
                "name": "starlark-format",
                "image": "owncloudci/bazel-buildifier",
                "commands": [
                    "buildifier --mode=check .drone.star",
                ],
            },
            {
                "name": "starlark-diff",
                "image": "owncloudci/bazel-buildifier",
                "commands": [
                    "buildifier --mode=fix .drone.star",
                    "git diff",
                ],
                "when": {
                    "status": [
                        "failure",
                    ],
                },
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

    return lint

def steps(config):
    return prepublish(config) + sleep(config) + assert(config) + server(config) + wait(config) + tests(config) + publish(config) + cleanup(config)
