# AwaysDogContracts

A collection of smart contracts for the AlwaysDog (ADOG) token ecosystem on BNB Chain. This project implements an ERC20 token with batch swapping capabilities via PancakeSwap V3.

## Contracts Overview

### AlwaysDog.sol
An upgradeable ERC20 token contract for the ADOG token with the following features:
- Maximum supply of 1 billion tokens
- Designated minter role for controlled token minting
- Owner-controlled minter management
- OpenZeppelin's upgradeable contract pattern

### BatchSwapper.sol
A utility contract that allows users to:
- Swap BNB for multiple tokens in a single transaction
- Swap multiple tokens for BNB in a single transaction
- Receive ADOG tokens for using the swapping service
- Configurable fee structure and swap limits
- Support for multiple token pools with different fee tiers

### ADOGFactory.sol
A factory contract that deploys and links the AlwaysDog and BatchSwapper contracts:
- Creates transparent upgradeable proxies for both contracts
- Sets up initial configuration between contracts
- Transfers ownership to the deployer after setup

### Interface Contracts
- **ISwapRouter.sol**: Interface for the PancakeSwap V3 router
- **IPancakeV3SwapCallback.sol**: Callback interface required for PancakeSwap V3 swaps

## Key Features
- Upgradeable contract architecture for future improvements
- Security features including reentrancy protection and pausability
- Owner rescue functionality for emergency token recovery
- Gas-efficient batch operations

## Technical Architecture
The system uses OpenZeppelin's upgradeable contracts pattern with transparent proxies. The ADOGFactory contract orchestrates the deployment and linking of the AlwaysDog token and BatchSwapper utility.

## Dependencies
- OpenZeppelin Contracts
- PancakeSwap V3 interfaces

## Commands
- `yarn compile` - Compile the smart contracts
- `yarn clean` - Remove the build artifacts and cache
- `yarn flatten` - Flatten the contracts for verification

## License
[Apache License 2.0](https://raw.githubusercontent.com/AlwaysDog/AlwaysDogContracts/refs/heads/main/LICENSE)