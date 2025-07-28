# Cross-Chain Atomic Swap Protocol

A secure cross-chain atomic swap protocol built on Aptos that enables trustless asset swaps across different blockchains. This is the Aptos implementation of the [1inch Fusion Plus](https://github.com/1inch/cross-chain-swap) protocol.

## Overview

The protocol enables secure cross-chain swaps through a clean separation of concerns with hashlocked and timelocked escrows. It consists of several key components that work together to provide a secure, trustless cross-chain swap experience.

### Core Components

1. **Fusion Orders (`fusion_order.move`)**
   - User-created orders that can be cancelled before pickup
   - **Users only deposit main asset (no safety deposit)**
   - **Resolvers provide safety deposit when accepting orders**
   - Order cancellation by owner
   - Friend function for converting to escrow

2. **Escrow (`escrow.move`)**
   - Secure asset escrow with timelock and hashlock protection
   - Two creation methods: from fusion order or directly from resolver
   - **Assets locked in escrow (not with resolver)**
   - **Only resolvers can call withdraw**
   - Timelock-based phase management
   - Hashlock-based secret verification
   - Asset withdrawal and cancellation logic
   - **Source chain: resolver gets tokens**
   - **Destination chain: user gets tokens**

3. **Resolver Registry (`resolver_registry.move`)**
   - Resolver registration and status management
   - Admin functions for resolver management

4. **Timelock (`timelock.move`)**
   - Phase management for escrow lifecycle
   - Configurable duration validation
   - Phase transition logic
   - Individual phase duration validation

5. **Hashlock (`hashlock.move`)**
   - Secret verification for asset withdrawal
   - Hash-based security mechanism

6. **Constants (`libs/constants.move`)**
   - Protocol-wide configuration
   - Safety deposit settings
   - Timelock duration defaults

### Architecture Flow

```
[SOURCE CHAIN]                       [DESTINATION CHAIN]

User creates Fusion Order
         ↓
   [Can be cancelled by user]
         ↓
Resolver accepts order              Resolver creates escrow
         ↓                                   ↓
   Fusion Order → Escrow                Escrow
         ↓                                   ↓
   [Assets locked in escrow]         [Assets locked in escrow]
         ↓                                   ↓
                    [Timelock phases begin]
                                 ↓
                    [Hashlock protection active]
                                 ↓
                    [Only resolver can withdraw]
                                 ↓
                    [Destination: User gets tokens]
                                 ↓
                    [Source: Resolver gets tokens]
```

### Cross-Chain Atomic Swap Flow

1. **Order Creation**
   - User creates fusion order with main asset only
   - No safety deposit from user (resolver provides later)

2. **Order Acceptance**
   - Resolver monitors `FusionOrderCreatedEvent`
   - Resolver provides safety deposit when accepting
   - Assets extracted for escrow creation (not to resolver)

3. **Escrow Creation**
   - Source chain escrow created with user's assets + resolver's safety deposit
   - Resolver creates matching destination chain escrow
   - Both escrows use same hashlock secret

4. **Withdrawal Process**
   - **Only resolvers can call withdraw**
   - **Destination chain first**: User gets tokens, resolver gets safety deposit
   - **Source chain second**: Resolver gets tokens, resolver gets safety deposit

### Timelock Phases

![Timelocks](assets/timelocks.png)

1. **Finality Phase**
   - Initial period where settings can be modified
   - Recipient can be set or updated
   - No withdrawals allowed

2. **Exclusive Phase**
   - Only intended recipient can claim assets
   - Requires valid secret for withdrawal
   - Hashlock verification required
   - **Only resolvers can withdraw**

3. **Private Cancellation Phase**
   - Owner can cancel and reclaim assets
   - Requires no prior withdrawal
   - Admin-only recovery

4. **Public Cancellation Phase**
   - Anyone with the correct secret can claim
   - Anyone can cancel if not claimed
   - Public recovery available

### Security Model

- **Hashlock Protection**: Assets locked until correct secret
- **Timelock Protection**: Phased access control
- **Cross-Chain Atomic**: Same secret works on both chains
- **Resolver Control**: Only resolvers can withdraw
- **User Protection**: Users never call withdraw
- **Safety Deposit**: Only resolvers provide safety deposits

### Economic Flow

1. **User**: Deposits main asset only (no safety deposit)
2. **Resolver**: Provides safety deposit when accepting order
3. **Escrow**: Locks both main asset and safety deposit
4. **Withdrawal**: 
   - Destination: User gets tokens, resolver gets safety deposit
   - Source: Resolver gets tokens, resolver gets safety deposit

## Project Structure

```
aptos-contracts/
├── sources/                   # Move smart contracts
│   ├── fusion_order.move      # Order creation and management
│   ├── escrow.move            # Hashed timelocked Escrow logic
│   ├── resolver_registry.move # Resolver management
│   ├── timelock.move          # Timelock management
│   ├── hashlock.move          # Hashlock verification
│   └── libs/
│       └── constants.move     # Protocol constants
├── tests/                     # Tests
│   ├── fusion_order_tests.move
│   ├── escrow_tests.move
│   ├── resolver_registry_tests.move
│   ├── timelock_tests.move
│   ├── hashlock_tests.move
│   └── helpers/
│       └── common.move        # Test utilities
└── Move.toml                  # Project configuration
```


## Requirements

Before you begin, you need to install the following tools:

- [Aptos CLI](https://aptos.dev/tools/aptos-cli/)
- [Move Prover](https://aptos.dev/tools/install-move-prover/)

## Quickstart

1. Build the project:
```bash
aptos move compile --dev
```

2. Run tests:
```bash
aptos move test --dev
```

3. Deploy the contracts:
```bash
aptos move publish --named-addresses aptos_fusion_plus=YOUR_ACCOUNT_ADDRESS
```

## Usage

### For Users

1. **Create Order**:
```move
fusion_order::new_entry(
    &signer,
    metadata,
    amount,
    chain_id,
    hash
);
```

2. **Cancel Order** (before resolver picks up):
```move
fusion_order::cancel(&signer, fusion_order);
```

### For Resolvers

1. **Monitor Events**: Listen for `FusionOrderCreatedEvent`
2. **Accept Order**: Call `escrow::new_from_order_entry()`
3. **Create Destination Escrow**: Match parameters from `FusionOrderAcceptedEvent`
4. **Withdraw**: Call `escrow::withdraw()` on both chains

## TODO

- Local testing
- Frontend
- Partial fills

## Hackathon bounties

### Extend Fusion+ to Aptos

This submission is an implementation of 1inch Fusion+ built with Aptos Move. One of the main differences between Move and EVM is that everything in Move is owned, unlike EVM where contracts can transfer user funds with prior approval. This means that the resolver cannot directly transfer the user's funds to the escrow on behalf of the user.

I solved this ownership challenge by implementing a two-step process: users first deposit funds into the `fusion_order.move` module, which stores the funds in an object that only the user and the Escrow module can interact with. The resolver can then withdraw with these pre-deposited funds when creating the escrow (in `escrow.move`). This maintains Move's security model while enabling the Fusion+ workflow.

**Key Protocol Alignments:**
- **Safety Deposits**: Only resolvers provide safety deposits (users never do)
- **Asset Flow**: Assets stay locked in escrow (not with resolver)
- **Withdrawal Control**: Only resolvers can call withdraw
- **Cross-Chain Atomic**: Proper source/destination chain flow

Until the resolver picks up the order, the user retains full control and can withdraw their funds from the `fusion_order` at any time, effectively cancelling their order. This provides users with the same flexibility as the EVM version while respecting Move's ownership principles.

Besides this, my implementation closely follows the EVM version's architecture, with everything divided into separate modules for clarity and readability: `fusion_order.move` handles order creation on maker side, `escrow.move` manages asset with a timelock and hashlock and `resolver_registry.move` manages the whitelisted resolvers.

- [Deployed smart contracts]()

### Extend Fusion+ to Any Other Chain
Since Movement uses the same smart contract language, I also deployed the contracts to Movement Network.

- [Deployed smart contracts]()
