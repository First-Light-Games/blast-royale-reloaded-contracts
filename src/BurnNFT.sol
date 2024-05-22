// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract BurnNFT {
    IERC721 public nft;
    mapping(address => uint256[]) public burnedIds;

    event NFTBurned(address indexed owner, uint256 indexed tokenId);

    constructor(address _nftAddress) {
        nft = IERC721(_nftAddress);
    }

    function bulkBurn(uint256[] memory tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 nftId = tokenIds[i];
            address nftOwner = nft.ownerOf(nftId);

            nft.safeTransferFrom(nftOwner, address(0x000000000000000000000000000000000000dEaD), nftId);

            burnedIds[nftOwner].push(nftId);

            emit NFTBurned(nftOwner, nftId);
        }
    }

    function getBurnedIds(address owner) external view returns (uint256[] memory) {
        return burnedIds[owner];
    }
}
