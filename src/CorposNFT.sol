// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./creator-tokens-standards/access/OwnableBasic.sol";
import "./creator-tokens-standards/access/OwnableInitializable.sol";
import "./creator-tokens-standards/erc721c/v2/ERC721C.sol";
import "./creator-tokens-standards/programmable-royalties/BasicRoyalties.sol";
import "@openzeppelin-v4/contracts/access/AccessControl.sol";

/**
 * @title ERC721CWithImmutableMinterRoyalties
 * @author Limit Break, Inc.
 * @notice Extension of ERC721C that allows for minters to receive royalties on the tokens they mint.
 *         The royalty fee is immutable and set at contract creation.
 * @dev These contracts are intended for example use and are not intended for production deployments as-is.
 */
contract CorposNFT is OwnableBasic, ERC721C, BasicRoyalties, AccessControl {
    using Strings for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private constant _totalSupply = 888;
    string public baseTokenURI;
    string public suffixURI;
    uint256 private _totalMinted;

    error NonexistentToken();
    error MaxSupplyReached();
    error TokenIDExceedsMaxSupply();

    constructor(
        address admin_,
        address minter_,
        address royaltyReceiver_,
        uint96 royaltyFeeNumerator_,
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI_,
        string memory suffixURI_
    ) ERC721OpenZeppelin(name_, symbol_) BasicRoyalties(royaltyReceiver_, royaltyFeeNumerator_) {
        baseTokenURI = baseTokenURI_;
        suffixURI = suffixURI_;

        _setupRole(ADMIN_ROLE, admin_);
        _setupRole(MINTER_ROLE, minter_);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721C, ERC2981, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function safeMint(address to, uint256 tokenId) external onlyRole(MINTER_ROLE) {
        if (_totalMinted >= _totalSupply) {
            revert MaxSupplyReached();
        }
        if (tokenId >= _totalSupply) {
            revert TokenIDExceedsMaxSupply();
        }

        _safeMint(to, tokenId);
        _totalMinted = _totalMinted + 1;
    }

    function _mint(address to, uint256 tokenId) internal virtual override {
        super._mint(to, tokenId);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function setBaseURI(string memory baseTokenURI_) public onlyRole(ADMIN_ROLE) {
        baseTokenURI = baseTokenURI_;
    }

    function setSuffixURI(string memory suffixURI_) public onlyRole(ADMIN_ROLE) {
        suffixURI = suffixURI_;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) {
            revert NonexistentToken();
        }
        return
            bytes(baseTokenURI).length > 0 ? string(abi.encodePacked(baseTokenURI, tokenId.toString(), suffixURI)) : "";
    }

    /// @dev Grants or revokes MINTER_ROLE
    // function setupMinter(address minter, bool enabled) external onlyRole(ADMIN_ROLE) {
    //     require(minter != address(0), "!minter");
    //     if (enabled) _setupRole(MINTER_ROLE, minter);
    //     else _revokeRole(MINTER_ROLE, minter);
    // }

    /// @dev Returns true if MINTER
    function isMinter(address minter) external view returns (bool) {
        return hasRole(MINTER_ROLE, minter);
    }

    /// @dev Returns true if ADMIN
    function isAdmin(address admin) external view returns (bool) {
        return hasRole(ADMIN_ROLE, admin);
    }
}
