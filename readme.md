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

> **Transfer Owner** to MultiSign Wallet
```bash
aptos move run \
    --function-id 0x1::object::transfer \
    --type-args 0x1::object::ObjectCore \
    --args address:0xcf25bce68c29766df9118ca05391e2fcd8eaeb8ac1011b2d6a70f24d05777b3b address:0xc654a6077e7bf14b0f93243eefee7e45571458dfab8a55a06a511a10a5742a47 \
    --profile tevi-developer5
```

> **Note**: Update the recipient address before running this command. - Should use from UI with Multisign Wallet

```bash
aptos move run \
    --function-id 'tevi-developer::TeviCoin::mint' \
    --args 'address:0x627a9d89698db452e5ba870d28430df8194286e3aaa806a98f29d34940e1556a' \
           'u64:10000000000000000000' \
    --profile tevi-developer \
    --assume-yes
```

```bash
aptos move run \
  --profile tevi-developer3 \
  --function-id 0x1::primary_fungible_store::transfer \
  --type-args 0x1::fungible_asset::Metadata \
  --args "address:0x4a60d406b7e5c786ee91a52fe6d1f5cd0a034301f5d80b5c6f83dc2e748f9a28" "address:0x427322fa4f6b9cad8c12be0cdaafe80368a0f8b77987df80d68d8f10f8a3186a" "u64:100000000"
```
