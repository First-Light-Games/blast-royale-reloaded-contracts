// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../interfaces/IEOARegistry.sol";
import "@openzeppelin-v4/contracts/utils/Context.sol";
import "@openzeppelin-v4/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin-v4/contracts/utils/cryptography/ECDSA.sol";

/// @dev Thrown when the caller does not match the recovered address for the signature.
error CallerDidNotSignTheMessage();

/// @dev Thrown when the caller has already been verified.
error SignatureAlreadyVerified();

/**
 * @title EOARegistry
 * @author Limit Break, Inc.
 * @notice A registry that may be used globally by any smart contract that limits contract interactions to verified EOA addresses only.
 * @dev Take care and carefully consider whether or not to use this. Restricting operations to EOA only accounts can break Defi composability,
 * so if Defi composability is an objective, this is not a good option.  Be advised that in the future, EOA accounts might not be a thing
 * but this is yet to be determined.  See https://eips.ethereum.org/EIPS/eip-4337 for more information.
 */
contract EOARegistry is Context, ERC165, IEOARegistry {
    /// @dev A pre-cached signed message hash used for gas-efficient signature recovery
    bytes32 private immutable signedMessageHash;

    /// @dev The plain text message to sign for signature verification
    string public constant MESSAGE_TO_SIGN = "EOA";

    /// @dev Mapping of accounts that to signature verification status
    mapping(address => bool) private eoaSignatureVerified;

    /// @dev Emitted whenever a user verifies that they are an EOA by submitting their signature.
    event VerifiedEOASignature(address indexed account);

    constructor() {
        signedMessageHash = ECDSA.toEthSignedMessageHash(bytes(MESSAGE_TO_SIGN));
    }

    /// @notice Allows a user to verify an ECDSA signature to definitively prove they are an EOA account.
    ///
    /// Throws when the caller has already verified their signature.
    /// Throws when the caller did not sign the message.
    ///
    /// Postconditions:
    /// ---------------
    /// The verified signature mapping has been updated to `true` for the caller.
    function verifySignature(bytes calldata signature) external {
        if (eoaSignatureVerified[_msgSender()]) {
            revert SignatureAlreadyVerified();
        }

        if (_msgSender() != ECDSA.recover(signedMessageHash, signature)) {
            revert CallerDidNotSignTheMessage();
        }

        eoaSignatureVerified[_msgSender()] = true;

        emit VerifiedEOASignature(_msgSender());
    }

    /// @notice Allows a user to verify an ECDSA signature to definitively prove they are an EOA account.
    /// This version is passed the v, r, s components of the signature, and is slightly more gas efficient than
    /// calculating the v, r, s components on-chain.
    ///
    /// Throws when the caller has already verified their signature.
    /// Throws when the caller did not sign the message.
    ///
    /// Postconditions:
    /// ---------------
    /// The verified signature mapping has been updated to `true` for the caller.
    function verifySignatureVRS(uint8 v, bytes32 r, bytes32 s) external {
        if (eoaSignatureVerified[msg.sender]) {
            revert SignatureAlreadyVerified();
        }

        if (msg.sender != ECDSA.recover(signedMessageHash, v, r, s)) {
            revert CallerDidNotSignTheMessage();
        }

        eoaSignatureVerified[msg.sender] = true;

        emit VerifiedEOASignature(msg.sender);
    }

    /// @notice Returns true if the specified account has verified a signature on this registry, false otherwise.
    function isVerifiedEOA(address account) public view override returns (bool) {
        return eoaSignatureVerified[account];
    }

    /// @dev ERC-165 interface support
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IEOARegistry).interfaceId || super.supportsInterface(interfaceId);
    }
}
