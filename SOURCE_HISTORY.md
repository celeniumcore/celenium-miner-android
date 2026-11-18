# Source history and contribution attribution

[Dimas A. Pradana (`dimas405`)](https://github.com/dimas405) maintains Celenium Miner. The owner also uses [`queenstack-dev`](https://github.com/queenstack-dev) for documentation work. These are aliases of the same maintainer, not a claim that two independent people developed the application.

The public backup retains the original Git author names, timestamps, and commit messages. New documentation commits attributed to `queenstack-dev` describe real changes to the README and source-history guidance. Older commits have not been reassigned to alter contribution rankings.

## Relationship to the Celenium node and Kaspa

This Flutter application connects to the separate Celenium network. Celenium's node code is a fork of [kaspanet/rusty-kaspa](https://github.com/kaspanet/rusty-kaspa).

The upstream project's [contributors](https://github.com/kaspanet/rusty-kaspa/graphs/contributors) include [`michaelsutton`](https://github.com/michaelsutton), [`someone235`](https://github.com/someone235), [`biryukovmaxim`](https://github.com/biryukovmaxim), [`aspect`](https://github.com/aspect), and [`tiram88`](https://github.com/tiram88). This is credit for upstream Kaspa work, not a statement that those developers wrote this Flutter application, maintain Celenium, or endorse this project.

Contributor graphs are generated from actual Git metadata. Links or acknowledgements do not make someone an author or collaborator in this repository.

## Reproducing the application source

Read the [README](README.md), [pubspec](pubspec.yaml), and Android project configuration for build prerequisites. Use the same signing identity when preparing updates for installed wallet applications. Keep recovery phrases, wallet keys, signing keystores, environment secrets, and access tokens outside Git.

The backup contains application source and its retained history. It does not contain wallet recovery data, production private keys, or Android signing keystores, and it is not a replacement for secure backups of those materials.

Source publication does not establish that mining shares were settled or that a participation claim was confirmed on-chain. Verify wallet balances against the node-backed API and blockchain state.

GitHub Actions is disabled for the backup repository. Build and test locally or on infrastructure authorized for the workload before enabling automation.
