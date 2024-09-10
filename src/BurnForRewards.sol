// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "./interfaces/IERC20Burnable.sol";
import "./interfaces/IERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Burnable.sol";

/// @title Burn Blast Equipments and CS for vouchers
/// @dev Blast Equipments ERC721 token
/// @dev Craft Spice (CS) ERC20 token
contract BurnForRewards is AccessControl, Pausable, ReentrancyGuard {
    enum Reward {
        BlastBucks,
        Noob
    }
    struct BurntAssets {
        uint256[] equipmentIdsForBB;
        uint256[] equipmentIdsForNoob;
        uint256 csAmountForBB;
        uint256 csAmountForNoob;
    }

    mapping(address => BurntAssets) public burntAssets;
    IERC20Burnable public craftSpice;
    IERC721 public blastEquipment;

    /// @notice Event Assets Burnt
    event AssetsBurnt(address burner, uint256[] equipmentIds, uint256 csAmount);

    /// @dev Setup the two contracts it will interact with : ERC721 and ERC20
    constructor(address _blastEquipment, address _craftSpice) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        blastEquipment = IERC721(_blastEquipment);
        craftSpice = IERC20Burnable(_craftSpice);
    }

    /// @dev burn blast equipments and CS for vouchers
    /// @param _tokenIds array of blast equipment token ids
    /// @param _csAmount amount of CS
    function burnAssetsForRewards(
        uint256[] memory _tokenIds,
        uint256 _csAmount,
        Reward reward
    ) public whenNotPaused nonReentrant {
        address burner = _msgSender();
        BurntAssets storage userAssets = burntAssets[burner];

        if (_csAmount > 0) {
            craftSpice.burnFrom(burner, _csAmount);
            if (reward == Reward.BlastBucks) {
                userAssets.csAmountForBB += _csAmount;
            } else if (reward == Reward.Noob) {
                userAssets.csAmountForNoob += _csAmount;
            }
        }

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(
                blastEquipment.ownerOf(_tokenIds[i]) == burner,
                "only owner can burn"
            );
            blastEquipment.burn(_tokenIds[i]);
            if (reward == Reward.BlastBucks) {
                userAssets.equipmentIdsForBB.push(_tokenIds[i]);
            } else if (reward == Reward.Noob) {
                userAssets.equipmentIdsForNoob.push(_tokenIds[i]);
            }
        }
        emit AssetsBurnt(burner, _tokenIds, _csAmount);
    }

    function getBurntAssets(
        address _address
    ) public view returns (BurntAssets memory) {
        BurntAssets memory _burntAssets = burntAssets[_address];
        return (_burntAssets);
    }

    function pause(bool stop) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (stop) {
            _pause();
        } else {
            _unpause();
        }
    }
}
