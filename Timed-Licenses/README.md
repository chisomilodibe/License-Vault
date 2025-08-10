# Digital Licensing Authority Smart Contract

A comprehensive blockchain-based system for creating, managing, and transferring time-bound digital licenses with granular access controls, ownership verification, and administrative oversight for decentralized license management.

## Overview

This smart contract provides a complete digital licensing solution built on the Stacks blockchain using Clarity. It enables the creation, management, transfer, and revocation of digital licenses with time-based expiration, transfer controls, and administrative oversight.

## Features

- **License Creation**: Issue new digital licenses with customizable validity periods
- **Time-Bound Licensing**: All licenses have configurable expiration timestamps
- **Transfer Management**: Enable or disable license transfers on a per-license basis
- **Portfolio Management**: Users can hold up to 20 licenses in their portfolio
- **Administrative Controls**: Admin functions for license management and system operations
- **Validity Verification**: Real-time license validity checking
- **System Pause**: Emergency system-wide pause functionality

## Contract Architecture

### State Variables
- `contract-administrator`: The principal with administrative privileges
- `license-counter`: Auto-incrementing counter for license IDs
- `system-paused`: System-wide pause flag
- `portfolio-filter-temp`: Temporary variable for portfolio filtering

### Data Structures

#### License Registry
```clarity
{
  license-holder: principal,
  issue-timestamp: uint,
  expiration-timestamp: uint,
  transfer-allowed: bool,
  license-status: bool,
  metadata-reference: (string-ascii 256)
}
```

#### License Portfolios
Each user can hold a maximum of 20 licenses, stored as a list of license IDs.

## Constants

- `maximum-licenses-per-holder`: 20 licenses per user
- `minimum-license-validity-period`: 1 block minimum validity
- `system-null-address`: System null address for validation

## Error Codes

| Code | Description |
|------|-------------|
| 100 | Insufficient permissions |
| 101 | Invalid license identifier |
| 102 | License expired |
| 103 | Transfer restrictions active |
| 104 | System maintenance mode |
| 105 | Redundant ownership request |
| 106 | Invalid time duration |
| 107 | Portfolio capacity exceeded |
| 108 | Duplicate license entry |
| 109 | Invalid wallet address |
| 110 | Missing metadata reference |

## Public Functions

### Read-Only Functions

#### `retrieve-license-details`
```clarity
(retrieve-license-details (license-identifier uint))
```
Returns complete license information for a given license ID.

#### `get-holder-license-collection`
```clarity
(get-holder-license-collection (wallet-address principal))
```
Returns the list of license IDs owned by a specific wallet.

#### `verify-license-validity`
```clarity
(verify-license-validity (license-identifier uint))
```
Checks if a license is currently valid (active and not expired).

#### `get-total-issued-licenses`
```clarity
(get-total-issued-licenses)
```
Returns the total number of licenses issued by the system.

#### `verify-administrative-privileges`
```clarity
(verify-administrative-privileges)
```
Checks if the current transaction sender has admin privileges.

#### `check-system-operational-status`
```clarity
(check-system-operational-status)
```
Returns the current system pause status.

### Write Functions

#### `issue-new-digital-license`
```clarity
(issue-new-digital-license 
  (license-recipient principal) 
  (validity-duration-blocks uint) 
  (enable-transfers bool)
  (metadata-reference (string-ascii 256)))
```
**Admin only.** Creates a new digital license with specified parameters.

**Parameters:**
- `license-recipient`: The wallet address that will receive the license
- `validity-duration-blocks`: License validity period in blocks
- `enable-transfers`: Whether the license can be transferred
- `metadata-reference`: Optional metadata string (max 256 characters)

**Returns:** The new license ID on success

#### `execute-license-transfer`
```clarity
(execute-license-transfer (license-identifier uint) (recipient-wallet principal))
```
Transfers ownership of a license to another wallet.

**Requirements:**
- Must be called by current license holder
- License must allow transfers
- License must be active and not expired
- Recipient portfolio must have space

#### `extend-license-validity`
```clarity
(extend-license-validity (license-identifier uint) (extension-blocks uint))
```
Extends the validity period of an existing license.

**Authorization:** Admin or license holder

#### `revoke-digital-license`
```clarity
(revoke-digital-license (license-identifier uint))
```
**Admin only.** Immediately revokes a license, making it invalid.

### Administrative Functions

#### `transfer-administrative-control`
```clarity
(transfer-administrative-control (new-administrator principal))
```
**Admin only.** Transfers administrative control to a new principal.

#### `toggle-system-operations`
```clarity
(toggle-system-operations (pause-system bool))
```
**Admin only.** Pauses or unpauses the entire system.

## Usage Examples

### Issuing a New License
```clarity
(contract-call? .digital-licensing-authority issue-new-digital-license 
  'SP1ABCD...  ;; recipient address
  u144000      ;; ~100 days validity
  true         ;; transfers allowed
  "Software License v1.0")
```

### Transferring a License
```clarity
(contract-call? .digital-licensing-authority execute-license-transfer 
  u1           ;; license ID
  'SP2EFGH...)  ;; new owner address
```

### Checking License Validity
```clarity
(contract-call? .digital-licensing-authority verify-license-validity u1)
```

## Security Features

1. **Administrative Controls**: Critical functions restricted to contract admin
2. **Input Validation**: Comprehensive validation of all inputs
3. **Portfolio Limits**: Maximum 20 licenses per holder prevents spam
4. **Transfer Controls**: Per-license transfer permissions
5. **Time-Based Expiration**: Automatic license expiration
6. **System Pause**: Emergency stop functionality
7. **Atomicity**: Transaction rollback on failure

## Limitations

- Maximum 20 licenses per wallet address
- Metadata limited to 256 ASCII characters
- Time-based expiration only (no other conditions)
- Single administrator model

## Deployment

1. Deploy the contract to the Stacks blockchain
2. The deployer becomes the initial administrator
3. Configure system parameters as needed
4. Begin issuing licenses

## Best Practices

1. **Regular Monitoring**: Check license expiration dates regularly
2. **Metadata Management**: Use standardized metadata formats
3. **Transfer Policies**: Carefully consider transfer permissions per license type
4. **Admin Key Security**: Secure the administrator private key properly
5. **System Maintenance**: Use pause functionality for upgrades