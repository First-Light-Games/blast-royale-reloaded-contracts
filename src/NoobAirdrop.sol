// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NoobAirdrop is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public merkleRoot;
    mapping(uint256 => bool) public claimed; // Tracks if an airdrop has been claimed by index
    IERC20 public noobToken;

    /// @notice Emit event when airdrop is claimed
    event AirdropClaimed(address claimer, uint256 index, uint256 amount);

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
    ) external whenNotPaused nonReentrant {
        // Check if already claimed
        require(!claimed[index], "Already claimed");

        // Verify proof
        require(verifyProof(proof, index, amount, msg.sender), "Invalid Proof");

        // Mark airdrop as claimed
        claimed[index] = true;

        require(
            noobToken.balanceOf(address(this)) >= amount,
            "$NOOB limit reached"
        );

        // Transfer tokens
        noobToken.safeTransfer(msg.sender, amount);

        emit AirdropClaimed(msg.sender, index, amount);
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
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function withdrawUnclaimedTokens(uint256 amount) external onlyOwner {
        require(
            noobToken.balanceOf(address(this)) >= amount,
            "Insufficient token balance"
        );
        noobToken.safeTransfer(owner(), amount);
    }

    function pause(bool stop) external onlyOwner {
        if (stop) {
            _pause();
        } else {
            _unpause();
        }
    }
}
