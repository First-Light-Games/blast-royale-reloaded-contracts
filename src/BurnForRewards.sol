// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "./interfaces/IBlastEquipmentNFTBurnable.sol";
import "./interfaces/IERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@magiceden-oss/erc721m/contracts/IERC721M.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title Burn Blast Equipments and CS for vouchers
/// @dev Blast Equipments ERC721 token
/// @dev Craft Spice (CS) ERC20 token
contract BurnBlastAssetsForRewards is AccessControl, Pausable, ReentrancyGuard {
    
    struct BurntAssets {
        uint256[] equipmentIds;
        uint256 csAmount;
    }

    mapping(address => BurntAssets) public burntAssets;
    IERC20Burnable public craftSpice;
    IBlastEquipmentNFT public blastEquipment;

    /// @notice Event Assets Burnt
    event AssetsBurnt(
        address burner,
        uint256[] equipmentIds,
        uint256 csAmount
    );

    /// @dev Setup the two contracts it will interact with : ERC721 and ERC20
    constructor(address _blastEquipment, address _craftSpice) {
         _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        blastEquipment = IBlastEquipmentNFT(_blastEquipment);
        craftSpice = IERC20Burnable(_craftSpice);
    }

    /// @dev burn blast equipments and CS for vouchers
    /// @param _tokenIds array of blast equipment token ids
    /// @param _csAmount amount of CS
    function burnAssetsForRewards(
        uint256[] memory _tokenIds,
        uint256 _csAmount
    ) public whenNotPaused nonReentrant {
        address burner = _msgSender();
        BurntAssets storage userAssets = burntAssets[burner];


        if (_csAmount > 0) {
            craftSpice.burnFrom(burner, _csAmount);
            userAssets.csAmount += _csAmount;
        }

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(
                blastEquipment.ownerOf(_tokenIds[i]) == burner,
                "only owner can burn"
            );
            blastEquipment.burn(_tokenIds[i]);
            userAssets.equipmentIds.push(_tokenIds[i]);
        }
        emit AssetsBurnt(burner, _tokenIds, _csAmount);
    }

    function getBurntAssets(
        address _address
    ) public view returns (uint256[] memory, uint256) {
        BurntAssets memory _burntAssets = burntAssets[_address];
        return (_burntAssets.equipmentIds, _burntAssets.csAmount);
    }

    function pause(bool stop) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (stop) {
            _pause();
        } else {
            _unpause();
        }
    }
}