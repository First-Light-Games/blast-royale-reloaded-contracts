//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.24;
pragma abicoder v2; // required to accept structs as function parameters

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Voucher} from "../src/Voucher.sol";

contract LazyERC20Distributor is Voucher, Ownable, Pausable, ReentrancyGuard {
    // Map signatureType/id to ERC20Address
    mapping(uint64 => ERC20) public whitelistedERC20Address;
    mapping(bytes16 => bool) internal idUsed;

    // Events
    event TokenWhitelisted(uint64 indexed tokenId, address erc20Token);
    event TokenRedeemed(
        address indexed wallet,
        uint64 signatureType,
        uint256 amount
    );
    event TokenWithdrawn(uint64 indexed tokenId, address to, uint256 amount);

    constructor(
        address _signerAddress,
        address _owner
    ) Voucher(_signerAddress) Ownable(_owner) {}

    /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
    /// @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
    function redeem(
        NFTVoucher calldata voucher
    ) public whenNotPaused nonReentrant {
        require(IsValidSignature(voucher), "Signature invalid or unauthorized");
        require(!idUsed[voucher.voucherId], "Voucher had been used");
        address tokenAddress = address(
            whitelistedERC20Address[voucher.signatureType]
        );
        require(tokenAddress != address(0), "Token is not whitelisted");
        ERC20 token = ERC20(tokenAddress);
        uint256 tokenAmount = uint256(voucher.data[0]);
        require(
            token.balanceOf(address(this)) >= tokenAmount,
            "Insufficient token balance in contract"
        );
        idUsed[voucher.voucherId] = true;
        token.transfer(voucher.wallet, tokenAmount);
        emit TokenRedeemed(voucher.wallet, voucher.signatureType, tokenAmount);
    }

    function whitelistToken(
        uint64 tokenId,
        address erc20Token
    ) public onlyOwner {
        require(
            address(whitelistedERC20Address[tokenId]) == address(0),
            "TokenId had already been used"
        );
        whitelistedERC20Address[tokenId] = ERC20(erc20Token);
        emit TokenWhitelisted(tokenId, erc20Token);
    }

    function getWhitelistedToken(
        uint64 tokenId
    ) external view returns (address) {
        return address(whitelistedERC20Address[tokenId]);
    }

    function withdrawToken(
        uint64 tokenId
    ) public onlyOwner whenNotPaused nonReentrant {
        address tokenAddress = address(whitelistedERC20Address[tokenId]);
        require(tokenAddress != address(0), "TokenId is invalid");

        ERC20 token = ERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner(), balance);
        emit TokenWithdrawn(tokenId, owner(), balance);
    }

    function setSignerAddress(address signer) public onlyOwner {
        Voucher.signerAddress = signer;
    }
}
