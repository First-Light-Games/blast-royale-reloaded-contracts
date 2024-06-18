// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IBlastEquipmentNFTBurnable.sol";
import "./interfaces/IERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@magiceden-oss/erc721m/contracts/IERC721M.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Errors} from "./libraries/Errors.sol";

/// @title Burn Blast Equipments and CS for vouchers
/// @dev Blast Equipments ERC721 token
/// @dev Craft Spice (CS) ERC20 token
contract BurnBlastAssetsForRewards is AccessControl, Pausable, ReentrancyGuard {
    enum Reward {
        BlastBucks,
        BLST
    }

    struct BurntAssets {
        uint256[] equipmentIds;
        uint256 csAmount;
    }

    bool public onlyRewardBlastBucks;
    mapping(address => mapping(Reward => BurntAssets)) public burntAssets;
    IERC20Burnable public craftSpice;
    IBlastEquipmentNFT public blastEquipment;

    /// @notice Event Assets Burnt
    event AssetsBurnt(
        address burner,
        uint256[] equipmentIds,
        uint256 csAmount,
        Reward reward
    );

    /// @dev Setup the two contracts it will interact with : ERC721 and ERC20
    constructor(address _blastEquipment, address _craftSpice) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        blastEquipment = IBlastEquipmentNFT(_blastEquipment);
        craftSpice = IERC20Burnable(_craftSpice);
        onlyRewardBlastBucks = true;
    }

    /// @dev burn blast equipments and CS for vouchers
    /// @param _tokenIds array of blast equipment token ids
    /// @param _csAmount amount of CS
    /// @param reward enum of either BLST or BlastBucks for reward
    function burnAssetsForRewards(
        uint256[] memory _tokenIds,
        uint256 _csAmount,
        Reward reward
    ) public whenNotPaused nonReentrant {
        if (onlyRewardBlastBucks) {
            require(
                reward == Reward.BlastBucks,
                "only rewarding Blast Bucks now"
            );
        }
        address burner = _msgSender();
        BurntAssets storage userAssets = burntAssets[burner][reward];
        uint256 assetLength = userAssets.equipmentIds.length;

        if (_csAmount > 0) {
            craftSpice.burnFrom(burner, _csAmount);
        }

        // Iterate through token IDs
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(
                blastEquipment.ownerOf(_tokenIds[i]) == burner,
                "only owner can burn"
            );
            // Burn NFTs
            blastEquipment.burn(_tokenIds[i]);

            // Push token ID if the array is non-empty
            if (assetLength > 0) {
                userAssets.equipmentIds.push(_tokenIds[i]);
            }
        }

        // Update or create burnt assets
        if (assetLength == 0) {
            burntAssets[burner][reward] = BurntAssets(_tokenIds, _csAmount);
        } else {
            userAssets.csAmount += _csAmount;
        }

        emit AssetsBurnt(burner, _tokenIds, _csAmount, reward);
    }

    function setOnlyRewardBlastBucks(
        // @audit external function if no other contracts are calling
        bool isOnlyBlastBucks
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        onlyRewardBlastBucks = isOnlyBlastBucks;
    }

    // Getter function for BurntAssets
    function getBurntAssets(
        address _address,
        Reward reward
    ) public view returns (uint256[] memory, uint256) {
        BurntAssets memory _burntAssets = burntAssets[_address][reward];
        return (_burntAssets.equipmentIds, _burntAssets.csAmount);
    }

    // @notice Pauses/Unpauses the contract
    // @dev While paused, addListing, and buy are not allowed
    // @param stop whether to pause or unpause the contract.
    function pause(bool stop) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (stop) {
            _pause();
        } else {
            _unpause();
        }
    }
}