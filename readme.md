# TeviCoin - Aptos Cli Version `6.1.1`

This document outlines the main commands for managing the TeviCoin project on the Aptos blockchain.

## Setup

### Initialize Developer Profile
```bash
aptos init --network testnet --profile tevi-developer
```

## Development

### Compile Move Code
```bash
aptos move compile --named-addresses TeviCoin=tevi-developer
```

### Run Tests
```bash
aptos move test --named-addresses TeviCoin=tevi-developer
```

### Deploy Contract
```bash
aptos move publish --named-addresses TeviCoin=tevi-developer --profile tevi-developer
```

## Token Operations

### Mint TEVI Tokens
Mints 100 billion TEVI tokens to the TeviOwner address.

> **Note**: Update the recipient address before running this command.

```bash
aptos move run \
    --function-id 'tevi-developer::TeviCoin::mint' \
    --args 'address:0x8f0caa40a65cb5c62e1201772ab560c7f13644cc31cc2b83b1af0008d27b21d4' \
           'u64:10000000000000000000' \
    --profile tevi-developer \
    --assume-yes
```