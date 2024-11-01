## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

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

### Deploy

```shell
source .env
```

```shell
forge script ./script/NoobFlexibleStaking.s.sol:NoobFlexibleStakingScript --chain sepolia --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
```

```shell
forge script ./script/NoobFixedStaking.s.sol:NoobFixedStakingScript --chain sepolia --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
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

### Deployment (on Sepolia)
FixedStaking: https://sepolia.etherscan.io/address/0x1c68b66261addfe388969eb6c44641dfd995d52f
FlexibleStaking: https://sepolia.etherscan.io/address/0x4035670e45f04b649f3ae7e4f9fc579261a18d22
Noob: https://sepolia.etherscan.io/address/0x7866fbb00a197d5abab0ab666f045c2caa879ffc