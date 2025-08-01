# Aptos Fusion Plus - Explorer Function Parameters

This document provides function parameters for testing the complete cross-chain atomic swap flow in the Aptos Explorer.

## Contract Addresses

**Testnet:**
- Account Address: `0x2cb2b191738c0c6311314ea06c4c8e489db62c8df1a72c11bdd3192186ed8eac`
- Package Name: `aptos_fusion_plus`

**Devnet:**
- Account Address: `0x2cb2b191738c0c6311314ea06c4c8e489db62c8df1a72c11bdd3192186ed8eac`
- Package Name: `aptos_fusion_plus`

## Complete Flow Testing Parameters

### 1. Register Resolver (Admin Only)

**Function:** `resolver_registry::register_resolver`

**Parameters:**
```json
{
  "signer": "0x2cb2b191738c0c6311314ea06c4c8e489db62c8df1a72c11bdd3192186ed8eac",
  "address": "0x1234567890123456789012345678901234567890123456789012345678901234"
}
```

**Alternative Vector Format:**
```
signer: 0x2cb2b191738c0c6311314ea06c4c8e489db62c8df1a72c11bdd3192186ed8eac
address: 0x1234567890123456789012345678901234567890123456789012345678901234
```

### 2. Create Fusion Order (User)

**Function:** `fusion_order::new_entry`

**Parameters:**
```json
{
  "signer": "0x2cb2b191738c0c6311314ea06c4c8e489db62c8df1a72c11bdd3192186ed8eac",
  "source_metadata": "0xa",
  "source_amount": 1000000,
  "destination_asset": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  "destination_recipient": [116, 45, 53, 204, 102, 52, 192, 83, 41, 37, 163, 184, 212, 201, 219, 150, 196, 180, 139, 119],
  "chain_id": 137,
  "hash": [18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52],
  "initial_destination_amount": 1000000,
  "min_destination_amount": 900000,
  "decay_per_second": 100
}
```

**Alternative Vector Format:**
```
signer: 0x2cb2b191738c0c6311314ea06c4c8e489db62c8df1a72c11bdd3192186ed8eac
source_metadata: 0xa
source_amount: 1000000
destination_asset: 0x0000000000000000000000000000000000000000000000000000000000000000
destination_recipient: 0x742d35cc6634c0532925a3b8d4c9db96c4b4d8b7
chain_id: 137
hash: 0x12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678
initial_destination_amount: 1000000
min_destination_amount: 900000
decay_per_second: 100
```

**Parameter Explanations:**
- `source_metadata`: Aptos token metadata object (0xa for APT)
- `source_amount`: Amount to swap (1,000,000 = 1 APT)
- `destination_asset`: Native asset (all zeros) or EVM token address
- `destination_recipient`: EVM address (20 bytes) for destination chain
- `chain_id`: Destination chain ID (137 = Polygon)
- `hash`: 32-byte hash of the secret for cross-chain verification
- `initial_destination_amount`: Starting Dutch auction price
- `min_destination_amount`: Minimum acceptable price (floor)
- `decay_per_second`: Price decay rate for Dutch auction

### 3. Accept Fusion Order (Resolver)

**Function:** `escrow::new_from_order_entry`

**Parameters:**
```json
{
  "resolver": "0x1234567890123456789012345678901234567890123456789012345678901234",
  "fusion_order": "0x7890123456789012345678901234567890123456789012345678901234567890"
}
```

**Alternative Vector Format:**
```
resolver: 0x1234567890123456789012345678901234567890123456789012345678901234
fusion_order: 0x7890123456789012345678901234567890123456789012345678901234567890
```

**Parameter Explanations:**
- `resolver`: Resolver's signer address (must be registered)
- `fusion_order`: Object address of the fusion order to accept

### 4. Create Destination Chain Escrow (Resolver)

**Function:** `escrow::new_from_resolver_entry`

**Parameters:**
```json
{
  "resolver": "0x1234567890123456789012345678901234567890123456789012345678901234",
  "recipient_address": [116, 45, 53, 204, 102, 52, 192, 83, 41, 37, 163, 184, 212, 201, 219, 150, 196, 180, 139, 119],
  "metadata": "0xa",
  "amount": 950000,
  "chain_id": 137,
  "hash": [18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52]
}
```

**Alternative Vector Format:**
```
resolver: 0x1234567890123456789012345678901234567890123456789012345678901234
recipient_address: 0x742d35cc6634c0532925a3b8d4c9db96c4b4d8b7
metadata: 0xa
amount: 950000
chain_id: 137
hash: 0x12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678
```

**Parameter Explanations:**
- `resolver`: Resolver's signer address
- `recipient_address`: EVM address that will receive tokens on destination chain
- `metadata`: Token metadata (must match source chain)
- `amount`: Amount to send (should match current Dutch auction price from source chain)
- `chain_id`: Destination chain ID
- `hash`: Same hash as source chain escrow

### 5. Withdraw from Destination Chain (Resolver)

**Function:** `escrow::withdraw`

**Parameters:**
```json
{
  "signer": "0x1234567890123456789012345678901234567890123456789012345678901234",
  "escrow": "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  "secret": [18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52]
}
```

**Alternative Vector Format:**
```
signer: 0x1234567890123456789012345678901234567890123456789012345678901234
escrow: 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
secret: 0x12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678
```

**Parameter Explanations:**
- `signer`: Resolver's signer address
- `escrow`: Destination chain escrow object address
- `secret`: The actual secret that matches the hash (32 bytes)

### 6. Withdraw from Source Chain (Resolver)

**Function:** `escrow::withdraw`

**Parameters:**
```json
{
  "signer": "0x1234567890123456789012345678901234567890123456789012345678901234",
  "escrow": "0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
  "secret": [18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52]
}
```

**Alternative Vector Format:**
```
signer: 0x1234567890123456789012345678901234567890123456789012345678901234
escrow: 0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321
secret: 0x12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678
```

**Parameter Explanations:**
- `signer`: Resolver's signer address
- `escrow`: Source chain escrow object address
- `secret`: Same secret used for destination chain withdrawal

## Alternative Flow: Direct Escrow Creation

### Create Source Chain Escrow Directly

**Function:** `escrow::new_from_resolver_entry`

**Parameters:**
```json
{
  "resolver": "0x1234567890123456789012345678901234567890123456789012345678901234",
  "recipient_address": [18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52],
  "metadata": "0xa",
  "amount": 1000000,
  "chain_id": 1,
  "hash": [18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52]
}
```

**Alternative Vector Format:**
```
resolver: 0x1234567890123456789012345678901234567890123456789012345678901234
recipient_address: 0x1234567890123456789012345678901234567890123456789012345678901234
metadata: 0xa
amount: 1000000
chain_id: 1
hash: 0x12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678
```

## Recovery Functions

### Cancel Fusion Order (User)

**Function:** `fusion_order::cancel`

**Parameters:**
```json
{
  "signer": "0x2cb2b191738c0c6311314ea06c4c8e489db62c8df1a72c11bdd3192186ed8eac",
  "fusion_order": "0x7890123456789012345678901234567890123456789012345678901234567890"
}
```

**Alternative Vector Format:**
```
signer: 0x2cb2b191738c0c6311314ea06c4c8e489db62c8df1a72c11bdd3192186ed8eac
fusion_order: 0x7890123456789012345678901234567890123456789012345678901234567890
```

### Recover Escrow (Resolver or Anyone)

**Function:** `escrow::recovery`

**Parameters:**
```json
{
  "signer": "0x1234567890123456789012345678901234567890123456789012345678901234",
  "escrow": "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
}
```

**Alternative Vector Format:**
```
signer: 0x1234567890123456789012345678901234567890123456789012345678901234
escrow: 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
```

## Admin Functions

### Activate/Deactivate Resolver

**Function:** `resolver_registry::set_resolver_status`

**Parameters:**
```json
{
  "signer": "0x2cb2b191738c0c6311314ea06c4c8e489db62c8df1a72c11bdd3192186ed8eac",
  "address": "0x1234567890123456789012345678901234567890123456789012345678901234",
  "status": true
}
```

**Alternative Vector Format:**
```
signer: 0x2cb2b191738c0c6311314ea06c4c8e489db62c8df1a72c11bdd3192186ed8eac
address: 0x1234567890123456789012345678901234567890123456789012345678901234
status: true
```

## Testing Scenarios

### Scenario 1: Complete Successful Swap
1. Register resolver
2. Create fusion order
3. Accept fusion order (creates source escrow)
4. Create destination escrow
5. Withdraw from destination chain
6. Withdraw from source chain

### Scenario 2: Order Cancellation
1. Create fusion order
2. Cancel fusion order (before resolver accepts)

### Scenario 3: Escrow Recovery
1. Create escrow
2. Wait for timelock phases
3. Call recovery function

### Scenario 4: Dutch Auction
1. Create fusion order with decay parameters
2. Monitor price changes
3. Resolver accepts at optimal price

## Important Notes

1. **Object Addresses**: Object addresses are generated dynamically and must be obtained from events or previous function calls.

2. **Hash and Secret**: The hash is the SHA256 of the secret. Both must be 32 bytes.

3. **Chain IDs**: 
   - 1 = Aptos (source chain)
   - 137 = Polygon
   - 1 = Ethereum
   - 56 = BSC

4. **Safety Deposit**: Resolvers must have sufficient safety deposit tokens (100,000 units of the safety deposit token).

5. **Timelock Phases**: 
   - Finality: 12 seconds (no actions)
   - Exclusive: 12 seconds (resolver withdrawal only)
   - Public: 96 seconds (anyone with secret)
   - Cancellation: 60 seconds (resolver recovery)
   - Public Cancellation: 60 seconds (anyone recovery)

6. **Cross-Chain Coordination**: Resolvers must monitor events on both chains and ensure atomic swap completion.

## Aptos Explorer Format Guidelines

### Data Types:
- **Numbers**: Use without quotes (e.g., `1000000`, not `"1000000"`)
- **Booleans**: Use without quotes (e.g., `true`, not `"true"`)
- **Vectors**: Can be provided as JSON arrays `[1, 2, 3]` or comma-separated values `0x1, 0x2, 0x3`
- **Option Types**: Use `null` for `Option::none` or provide the actual value

### Vector Examples:
```json
// JSON Array format
"destination_asset": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

// Comma-separated format
destination_asset: 0x0000000000000000000000000000000000000000000000000000000000000000
```

### Address Formats:
- **Aptos Addresses**: Use full 32-byte format
- **EVM Addresses**: Use 20-byte format for destination recipients
- **Native Assets**: Use all zeros `[0, 0, 0, 0, ...]` for native tokens
