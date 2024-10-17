// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NoobAirdrop is Ownable {
    using SafeERC20 for IERC20;

    bytes32 public merkleRoot;
    BitMaps.BitMap private _airdropList;
    IERC20 public noobToken;

    constructor(
        bytes32 _merkleRoot,
        IERC20 _noobToken,
        address owner
    ) Ownable(owner) {
        merkleRoot = _merkleRoot;
        noobToken = _noobToken;
    }

    function claimAirDrop(
        bytes32[] calldata proof,
        uint256 index,
        uint256 amount
    ) external {
        // check if already claimed
        require(!hasClaimed(index), "Already claimed");

        // verify proof
        require(verifyProof(proof, index, amount, msg.sender), "Invalid Prood");

        // set airdrop as claimed
        BitMaps.setTo(_airdropList, index, true);

        require(
            noobToken.balanceOf(address(this)) >= amount,
            "$NOOB limit reached"
        );
        // transfer tokens
        noobToken.safeTransfer(msg.sender, amount);
    }

    function verifyProof(
        bytes32[] memory proof,
        uint256 index,
        uint256 amount,
        address addr
    ) public view returns (bool) {
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(addr, index, amount)))
        );
        if (MerkleProof.verify(proof, merkleRoot, leaf)) {
            return true;
        } else {
            return false;
        }
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function hasClaimed(uint256 index) public view returns (bool) {
        if (BitMaps.get(_airdropList, index)) {
            return true;
        } else {
            return false;
        }
    }
}
