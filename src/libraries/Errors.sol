// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title Errors library
 * @author JensonCollins
 * @notice Defines the error messages emitted by the different contracts of the Aave protocol
 * @dev Error messages prefix glossary:
 *  - VL = ValidationLogic
 *  - MATH = Math libraries
 *  - CT = Common errors between tokens (AToken, VariableDebtToken and StableDebtToken)
 *  - AT = AToken
 *  - SDT = StableDebtToken
 *  - VDT = VariableDebtToken
 *  - LP = LendingPool
 *  - LPAPR = LendingPoolAddressesProviderRegistry
 *  - LPC = LendingPoolConfiguration
 *  - RL = ReserveLogic
 *  - LPCM = LendingPoolCollateralManager
 *  - P = Pausable
 */

library Errors {
    //common errors
    string public constant NO_ZERO_ADDRESS = "1"; // Address cannot be zero
    string public constant NO_ZERO_VALUE = "2"; // Value cannot be zero
    string public constant NOT_OWNER = "3"; // Caller is not owner
    string public constant NOT_EXIST_TOKEN_ID = "4"; // Token ID does not exist
    string public constant INVALID_PARAM = "5"; // Invalid parameter
    string public constant INVALID_AMOUNT = "6"; // In case msg.value amount is different as expected
    string public constant FAILED_TO_SEND_ETHER_TREASURY = "7"; // Failed to send ether to treasury
    string public constant FAILED_TO_SEND_ETHER_COMPANY = "8"; // Failed to send ether to company
    string public constant USING_MATIC_NOW = "9"; // Using MATIC now
    string public constant NOT_USING_MATIC_NOW = "10"; // Not using MATIC now

    // AccessControl
    string public constant MISSING_GAME_ROLE = "11"; // Caller does not have the GAME_ROLE role

    // BlastEquipmentNFT contract
    string public constant MAX_LEVEL_REACHED = "12"; // Max level reached
    string public constant MAX_REPLICATION_COUNT_REACHED = "24"; // Max replication counter reached

    // Marektplace contract
    string public constant TOKEN_NOT_WHITELISTED = "13"; // Caller is not whitelisted
    string public constant LISTING_IS_NOT_ACTIVED = "14"; // Listing is not actived
    string public constant FAILED_TO_SEND_ETHER_USER = "15"; // Failed to send ether to user

    // MarketplaceLootbox contract
    string public constant MAX_LIMIT_REACHED = "16"; // Reached max limit
    string public constant INVALID_MERKLE_PROOF = "17"; // Invalid merkle proof

    // Lootbox contract
    string public constant NOT_AVAILABLE_TO_OPEN = "18"; // Lootbox is not available to open

    // CS contract
    string public constant CS_EXPIRED_DEADLINE = "19"; // Invalid signature
    string public constant CS_INVALID_SIGNATURE = "20"; // Invalid signature

    // Replicator contract
    string public constant NOT_READY_REPLICATE = "21"; // Not ready to replicate
    string public constant NOT_READY_MORPH = "22"; // Not ready to morph
    string public constant INVALID_HEX_CHARACTER = "23"; // Not ready to morph

    // Vesting contract
    string public constant INSUFFICIENT_TOKENS = "25"; // Insufficient tokens
    string public constant DURATION_INVALID = "26"; // Duration is invalid
    string public constant BENEFICIARY_OR_OWNER = "27"; // Beneficiary or owner
    string public constant NOT_ENOUGH_TOKENS = "28"; // Not enough tokens
    string public constant SCHEDULE_REVOKED = "29"; // Schedule revoked
    string public constant NOT_REVOCABLE = "30"; // Not revocable
    string public constant START_TIME_INVALID = "31"; // Start time is invalid
}
