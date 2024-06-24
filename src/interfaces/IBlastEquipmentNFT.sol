// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IERC721Burnable.sol";

struct StaticAttributes {
    uint8 maxLevel;
    uint8 maxDurability;
    uint8 maxReplication;
    uint8 adjective;
    uint8 rarity;
    uint8 grade;
}

/**
 * @dev required interface of an Equipment NFT.
 */
interface IBlastEquipmentNFT is IERC721 {
    /// @notice Event Attribute Updated
    event AttributeUpdated(
        uint256 tokenId,
        uint256 level,
        uint256 durabilityRestored,
        uint256 durability,
        uint256 lastRepairTime,
        uint256 repairCount,
        uint256 replicationCount
    );

    /// @notice Event Revealed TokenURI
    event PermanentURI(string _value, uint256 indexed _id);

    function safeMintReplicator(
        address _to,
        bytes32 _hash,
        string calldata _realUri,
        StaticAttributes calldata _staticAttribute
    ) external returns (uint);

    function revealRealTokenURI(uint _tokenId) external;

    function setRealTokenURI(uint _tokenId, string calldata _realUri) external;

    function setLevel(uint256 _tokenId, uint256 _newLevel) external;

    function setRepairCount(uint256 _tokenId, uint256 _newRepairCount) external;

    function setReplicationCount(
        uint256 _tokenId,
        uint256 _newReplicationCount
    ) external;

    function scrap(uint256 _tokenId) external;

    function getAttributes(
        uint256 _tokenId
    )
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256);

    function getStaticAttributes(
        uint256 _tokenId
    ) external view returns (uint8, uint8, uint8, uint8, uint8, uint8);
}