# Prime Intellect Incentives Network

**Prime Intellect is a global compute network that uses smart contracts facilitate trading and rewards between Compute Providers, Model Trainers, and Token Holders.**

This is a Proof-of-Concept (PoC) protocol to demonstrate the power and potential of adding incentives to a global compute network.

The goals of the PoC are as follows:

-   **Register models and compute nodes onchain**
-   **Run training models and submit attestations**
-   **Reward $PIN tokens for valid submissions**

# Documentation

-   **Prime Intellect Network Token (PIN)**: The native token of the Prime Intellect ecosystem.
-   **TrainingManager**: Swiss army knife for interacting with training logic. 
-   **StakingManager**: Manager of token governance for $PIN and training logic.

## Algorithm:

1. Compute nodes added to whitelist.
2. Compute nodes deposit/stake to the network. Compute nodes will be required to maintain a minimum amount of Prime Intellect tokens staked to the network.
3. Training starts, training attestations are submitted, and training ends.
4. Compute nodes can be slashed for providing fake or faulty attestation.
5. The Prime Intellect protocol can distribute PIN tokens to be claimed as rewards by compute providers.

See below for a system diagram of this process.

## System Diagram

![systemDiagram](./documentation/systemDiagram.jpg)

## File Overview:

- src
  - interfaces
  - PrimeIntellectToken.sol
  - StakingManager.sol
  - TrainingManager.sol
- test
  - RewardsTest.t.sol
  - ...
- lib
  - forge-std
  - openzeppelin-contracts
- client
  - PrimeIntellectRewards.py

## Developer Usage

This project was developed using forge and tested on a local anvil testnet.

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

Example result 9/30/24:

```
% forge test
[⠊] Compiling...
[⠒] Compiling 46 files with Solc 0.8.26
[⠢] Solc 0.8.26 finished in 2.08s
Compiler run successful!

Ran 1 test for test/EndToEndTest.t.sol:EndToEndTest
[PASS] testE2EBaseCase() (gas: 173629)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 9.44ms (1.70ms CPU time)

Ran 3 tests for test/StakingManagerTest.t.sol:StakingManagerTest
[PASS] testMultipleStakes() (gas: 334244)
[PASS] test_stake() (gas: 131441)
[PASS] test_withdraw() (gas: 100587)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 9.71ms (5.38ms CPU time)

Ran 4 tests for test/TrainingManager.t.sol:TrainingManagerTest
[PASS] test_JoinTrainingRun() (gas: 252055)
[PASS] test_StartAndSubmit() (gas: 452871)
[PASS] test_registerComputeNode() (gas: 72841)
[PASS] test_registerNewModel() (gas: 116856)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 9.73ms (7.43ms CPU time)

Ran 1 test for test/RewardsTest.t.sol:StakingManagerTest
[PASS] testClaimMultipleRuns() (gas: 2510203)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 10.26ms (2.51ms CPU time)

Ran 4 test suites in 165.54ms (39.13ms CPU time): 9 tests passed, 0 failed, 0 skipped (9 total tests)
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

# Future

- [ ] dynamic rewards per attestation
- [ ] stake to model training runs
- [ ] stake to compute nodes
- [ ] model trainer role
- [ ] challenge logic
- [ ] upgradeability
- [ ] testnet deploy
- [ ] security audit
- [ ] integration to existing Prime Intellect systems
