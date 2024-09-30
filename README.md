## Prime Intellect Incentives Network

**Prime Intellect is a global compute network that uses smart contracts facilitate trading and rewards between Compute Providers, Model Trainers, and Token Holders.**

This is a Proof-of-Concept (PoC) protocol to demonstrate the power and potential of adding incentives to a global compute network.

The goals of the PoC are as follows:

-   **Register models and compute nodes onchain**: tba.
-   **Run training models and submit attestations**: tba.
-   **Issue rewards in native token for submissions**: tba.

## Documentation

-   **Prime Intellect Network Token (PIN)**: The native token of the Prime Intellect ecosystem.
-   **TrainingManager**: Swiss army knife for interacting with EVM smart contracts, sending 

Compute nodes added to whitelist.
Compute nodes deposit/stake to the network. MIN deposit required.
Compute nodes will be required to maintain a minimum amount of Prime Intellect tokens staked to the network.
Compute nodes can be slashed for providing fake or faulty attestation.
The Prime Intellect protocol can distribute PIN tokens to be claimed as rewards by compute providers.

# System Diagram

![systemDiagram](./documentation/systemDiagram.jpg)

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy Locally

```shell
$ ./script/test.sh
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
