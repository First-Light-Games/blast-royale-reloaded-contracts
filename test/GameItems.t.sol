// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GameItems.sol";
import "../src/GameItemsForwarder.sol";
import "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

contract GameItemsTest is Test {
    GameItems gameItems;
    GameItemsForwarder forwarder;

    // Test accounts
    address deployer = address(this);
    address user1 = vm.addr(1); // Private key: 0x1
    address user2 = address(0x456);
    address relayer = address(0x789);

    // EIP-712 domain separator components
    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    function setUp() public {
        vm.startPrank(deployer);
        // Deploy the forwarder
        forwarder = new GameItemsForwarder();

        // Deploy GameItems with the forwarder address
        gameItems = new GameItems(
            address(forwarder),
            deployer,
            "ipfs://example/"
        );

        vm.stopPrank();
    }

    function computeDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712DOMAIN_TYPEHASH,
                    keccak256(bytes("GameItemsForwarder")),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(forwarder)
                )
            );
    }

    function testStandardTransfer() public {
        gameItems.mint(user1, 0, 100, "");
        console.log("gameItems.uri(0);", gameItems.uri(0));
        uint256 initialAmount = gameItems.balanceOf(address(user1), 0);
        uint256 transferAmount = 100;

        vm.prank(user1);
        gameItems.safeTransferFrom(user1, user2, 0, transferAmount, "");
        assertEq(
            gameItems.balanceOf(user1, 0),
            initialAmount - transferAmount,
            "user 1 initial balance should decrease"
        );
        assertEq(
            gameItems.balanceOf(user2, 0),
            transferAmount,
            "User 2 should have token id 0"
        );
    }

    function testGaslessTransfer() public {
        gameItems.mint(user1, 0, 100, "");
        uint256 initialNonce = forwarder.nonces(user1);

        // Prepare the ForwardRequestData
        ERC2771Forwarder.ForwardRequestData memory req = ERC2771Forwarder
            .ForwardRequestData({
                from: user1,
                to: address(gameItems),
                value: 0,
                gas: 1000000,
                deadline: uint48(block.timestamp + 1 hours),
                data: abi.encodeWithSelector(
                    gameItems.safeTransferFrom.selector,
                    user1,
                    user2,
                    0,
                    50,
                    ""
                ),
                signature: ""
            });

        // Compute TYPEHASH
        bytes32 TYPEHASH = keccak256(
            "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
        );

        // Compute the struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                TYPEHASH,
                req.from,
                req.to,
                req.value,
                req.gas,
                forwarder.nonces(req.from),
                req.deadline,
                keccak256(req.data)
            )
        );

        // Compute the EIP-712 digest with manual domain separator
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", computeDomainSeparator(), structHash)
        );

        // Sign the digest with user1’s private key (0x1)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        req.signature = abi.encodePacked(r, s, v);

        // Verify the request before execution
        assertTrue(forwarder.verify(req), "Signature should be valid");

        // Execute the request as the relayer
        vm.prank(relayer);
        vm.expectEmit(true, true, true, true);
        emit ERC2771Forwarder.ExecutedForwardRequest(user1, initialNonce, true);
        forwarder.execute(req);

        // Check balances
        assertEq(
            gameItems.balanceOf(user2, 0),
            50,
            "User2 should have 50 token 0"
        );
        assertEq(
            gameItems.balanceOf(user1, 0),
            50,
            "User1 token 0 should decrease"
        );

        // Check nonce increment
        assertEq(
            forwarder.nonces(user1),
            initialNonce + 1,
            "Nonce should increment"
        );
    }

    function testInvalidSignature() public {
        gameItems.mint(user1, 0, 100, "");

        ERC2771Forwarder.ForwardRequestData memory req = ERC2771Forwarder
            .ForwardRequestData({
                from: user1,
                to: address(gameItems),
                value: 0,
                gas: 1000000,
                deadline: uint48(block.timestamp + 1 hours),
                data: abi.encodeWithSelector(
                    gameItems.safeTransferFrom.selector,
                    user1,
                    user2,
                    0,
                    50,
                    ""
                ),
                signature: ""
            });

        bytes32 TYPEHASH = keccak256(
            "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                TYPEHASH,
                req.from,
                req.to,
                req.value,
                req.gas,
                forwarder.nonces(req.from),
                req.deadline,
                keccak256(req.data)
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", computeDomainSeparator(), structHash)
        );

        // Sign with wrong key (0x2)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, digest);
        req.signature = abi.encodePacked(r, s, v);

        assertFalse(
            forwarder.verify(req),
            "Invalid signature should not verify"
        );

        vm.prank(relayer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC2771Forwarder.ERC2771ForwarderInvalidSigner.selector,
                vm.addr(2),
                user1
            )
        );
        forwarder.execute(req);
    }

    function testExpiredDeadline() public {
        gameItems.mint(user1, 0, 100, "");

        ERC2771Forwarder.ForwardRequestData memory req = ERC2771Forwarder
            .ForwardRequestData({
                from: user1,
                to: address(gameItems),
                value: 0,
                gas: 1000000,
                deadline: uint48(block.timestamp - 1), // Expired
                data: abi.encodeWithSelector(
                    gameItems.safeTransferFrom.selector,
                    user1,
                    user2,
                    0,
                    50,
                    ""
                ),
                signature: ""
            });

        bytes32 TYPEHASH = keccak256(
            "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                TYPEHASH,
                req.from,
                req.to,
                req.value,
                req.gas,
                forwarder.nonces(req.from),
                req.deadline,
                keccak256(req.data)
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", computeDomainSeparator(), structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        req.signature = abi.encodePacked(r, s, v);

        assertFalse(
            forwarder.verify(req),
            "Expired deadline should not verify"
        );

        vm.prank(relayer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC2771Forwarder.ERC2771ForwarderExpiredRequest.selector,
                req.deadline
            )
        );
        forwarder.execute(req);
    }
}
