// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/CorposNFT.sol";
import "../src/creator-tokens-standards/utils/CreatorTokenTransferValidatorV2.sol";

contract CorposNFTTest is Test {
    using Strings for uint256;

    uint96 public constant FEE_DENOMINATOR = 10000;

    CorposNFT public tokenMock;
    uint96 public constant DEFAULT_ROYALTY_FEE_NUMERATOR = 1000;
    uint256 public constant maxSupply = 888;

    string public constant baseTokenURI = "https://www.test.com/";
    string public constant suffixURI = ".json";

    address minter1 = vm.addr(0x1);
    address minter2 = vm.addr(0x2);
    address adminAddress = vm.addr(0xa);

    address royaltyReceiver = address(this);

    CreatorTokenTransferValidatorV2 public validator;

    address validatorDeployer;
    address whitelistedOperator;

    function setUp() public {
        validatorDeployer = vm.addr(1);
        vm.startPrank(validatorDeployer);
        validator = new CreatorTokenTransferValidatorV2(validatorDeployer);
        vm.stopPrank();

        whitelistedOperator = vm.addr(2);

        vm.prank(validatorDeployer);
        validator.addOperatorToWhitelist(0, whitelistedOperator);

        tokenMock = new CorposNFT(
            adminAddress,
            royaltyReceiver,
            DEFAULT_ROYALTY_FEE_NUMERATOR,
            "Test",
            "TEST",
            baseTokenURI,
            suffixURI
        );


        vm.prank(adminAddress);
        tokenMock.setupMinter(address(this), true);
        vm.stopPrank();

        tokenMock.setToCustomValidatorAndSecurityPolicy(address(validator), TransferSecurityLevels.Recommended, 0);
    }

    function _mintToken(address tokenAddress, address to, uint256 tokenId) internal {
        CorposNFT(tokenAddress).safeMint(to, tokenId);
    }

    function testV2SupportedTokenInterfaces() public {
        assertEq(tokenMock.supportsInterface(type(ICreatorToken).interfaceId), true);
        assertEq(tokenMock.supportsInterface(type(IERC721).interfaceId), true);
        assertEq(tokenMock.supportsInterface(type(IERC721Metadata).interfaceId), true);
        assertEq(tokenMock.supportsInterface(type(IERC165).interfaceId), true);
    }

    function _safeMintToken(address tokenAddress, address to, uint256 tokenId) internal {
        CorposNFT(tokenAddress).safeMint(to, tokenId);
    }

    function testSupportedTokenInterfaces() public {
        assertEq(tokenMock.supportsInterface(type(ICreatorToken).interfaceId), true);
        assertEq(tokenMock.supportsInterface(type(IERC721).interfaceId), true);
        assertEq(tokenMock.supportsInterface(type(IERC721Metadata).interfaceId), true);
        assertEq(tokenMock.supportsInterface(type(IERC165).interfaceId), true);
        assertEq(tokenMock.supportsInterface(type(IERC2981).interfaceId), true);
    }

    function testFailRevertsWhenFeeNumeratorExceedsSalesPrice(uint96 royaltyFeeNumerator) public {
        vm.assume(royaltyFeeNumerator > FEE_DENOMINATOR);
        CorposNFT badToken = new CorposNFT(
            adminAddress, royaltyReceiver, royaltyFeeNumerator, "Test", "TEST", baseTokenURI, suffixURI
        );
        assertEq(address(badToken).code.length, 0);
    }

    function testRoyaltyInfoForUnmintedTokenIds(uint256 tokenId, uint256 salePrice) public {
        vm.assume(tokenId < maxSupply);

        vm.assume(salePrice < type(uint256).max / DEFAULT_ROYALTY_FEE_NUMERATOR);

        (address recipient, uint256 value) = tokenMock.royaltyInfo(tokenId, salePrice);
        console.log(recipient, value);
        assertEq(recipient, royaltyReceiver);
        assertEq(value, (salePrice * DEFAULT_ROYALTY_FEE_NUMERATOR) / FEE_DENOMINATOR);
    }

    function testRoyaltyInfoForMintedTokenIds(uint256 tokenId, uint256 salePrice) public {
        vm.assume(tokenId < maxSupply);

        address minter = vm.addr(0x1);
        vm.assume(salePrice < type(uint256).max / DEFAULT_ROYALTY_FEE_NUMERATOR);

        _mintToken(address(tokenMock), minter, tokenId);

        (address recipient, uint256 value) = tokenMock.royaltyInfo(tokenId, salePrice);
        assertEq(recipient, royaltyReceiver);
        assertEq(value, (salePrice * DEFAULT_ROYALTY_FEE_NUMERATOR) / FEE_DENOMINATOR);
    }

    function testTransfer(uint256 tokenId, uint256 salePrice) public {
        vm.assume(tokenId < maxSupply);

        address firstOwner = vm.addr(0xA11CE);
        address secondaryOwner = vm.addr(0xB0B);

        _mintToken(address(tokenMock), firstOwner, tokenId);

        assertEq(tokenMock.ownerOf(tokenId), firstOwner);
        vm.startPrank(firstOwner);
        tokenMock.transferFrom(firstOwner, secondaryOwner, tokenId);
        vm.stopPrank();
    }

    function testRoyaltyInfoForMintedTokenIdsAfterTransfer(uint256 tokenId, uint256 salePrice) public {
        vm.assume(tokenId < maxSupply);

        address firstOwner = vm.addr(0x199);
        address secondaryOwner = vm.addr(0x2);
        vm.assume(salePrice < type(uint256).max / DEFAULT_ROYALTY_FEE_NUMERATOR);

        _mintToken(address(tokenMock), firstOwner, tokenId);

        assertEq(tokenMock.ownerOf(tokenId), firstOwner);
        vm.startPrank(firstOwner);
        tokenMock.safeTransferFrom(firstOwner, secondaryOwner, tokenId);
        vm.stopPrank();

        (address recipient, uint256 value) = tokenMock.royaltyInfo(tokenId, salePrice);
        assertEq(recipient, royaltyReceiver);
        assertEq(value, (salePrice * DEFAULT_ROYALTY_FEE_NUMERATOR) / FEE_DENOMINATOR);
    }

    function testRoyaltyInfoForSafeMintedTokenIds(address minter, uint256 tokenId, uint256 salePrice) public {
        vm.assume(tokenId < maxSupply);

        vm.assume(minter != address(0));
        vm.assume(minter.code.length == 0);
        vm.assume(salePrice < type(uint256).max / DEFAULT_ROYALTY_FEE_NUMERATOR);
        _safeMintToken(address(tokenMock), minter, tokenId);
        (address recipient, uint256 value) = tokenMock.royaltyInfo(tokenId, salePrice);
        assertEq(recipient, royaltyReceiver);
        assertEq(value, (salePrice * DEFAULT_ROYALTY_FEE_NUMERATOR) / FEE_DENOMINATOR);
    }

    function testTokenURI(uint256 tokenId) public {
        vm.assume(tokenId < maxSupply);
        _safeMintToken(address(tokenMock), minter1, tokenId);
        assertEq(tokenMock.tokenURI(tokenId), string(abi.encodePacked(baseTokenURI, tokenId.toString(), suffixURI)));
    }

    function testFailTokenURI(uint256 tokenId) public {
        vm.assume(tokenId < maxSupply);
        string memory tokenURI = tokenMock.tokenURI(tokenId);
    }

    function testMaxSupply() public {
        assertEq(tokenMock.maxSupply(), maxSupply);
    }
    function testFailRoyaltyInfoUpdate() public {
        address nonAdminAddress = vm.addr(0xb);
        address newRoyaltyReceiver = vm.addr(0xc);

        vm.startPrank(nonAdminAddress);
        tokenMock.setDefaultRoyalty(newRoyaltyReceiver, 2000);
        vm.stopPrank();
    }
    function testRoyaltyInfoUpdate(address minter, uint256 tokenId, uint256 salePrice) public {
        vm.assume(tokenId < maxSupply);
        vm.assume(minter != address(0));
        vm.assume(minter.code.length == 0);

        vm.assume(salePrice < type(uint256).max / DEFAULT_ROYALTY_FEE_NUMERATOR && salePrice > 2000);
        _safeMintToken(address(tokenMock), minter, tokenId);
        (address recipient, uint256 value) = tokenMock.royaltyInfo(tokenId, salePrice);
        assertEq(recipient, royaltyReceiver);
        assertEq(value, (salePrice * DEFAULT_ROYALTY_FEE_NUMERATOR) / FEE_DENOMINATOR);

        address newRoyaltyReceiver = vm.addr(0xb);
        uint96 newFeeNumerator = 200;

        vm.startPrank(adminAddress);
        tokenMock.setDefaultRoyalty(newRoyaltyReceiver, newFeeNumerator);
        vm.stopPrank();


        (address recipient2, uint256 value2) = tokenMock.royaltyInfo(tokenId, salePrice);
        assertEq(recipient2, newRoyaltyReceiver);
        assertEq(value2, (salePrice * newFeeNumerator) / FEE_DENOMINATOR);
    }
}
