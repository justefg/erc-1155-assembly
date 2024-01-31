// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./lib/YulDeployer.sol";

interface ERC1155Yul {
    function mint(address,uint,uint) external;
    function mintBatch(address, uint[] calldata, uint[] calldata) external;
    function balanceOf(address, uint) external view returns(uint);
    function balanceOfBatch(address[] calldata, uint[] calldata) external view returns(uint[] memory);
    function safeTransferFrom(address,address,uint256,uint256) external;
    function safeTransferFromBatch(address, address, uint256[] calldata, uint256[] calldata) external;
    function setURI(string memory) external;
    function getURI() external view returns(string memory);

    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
}

contract ERC1155YulTest is Test {
    YulDeployer yulDeployer = new YulDeployer();
    ERC1155Yul public nftContract;

    address public owner = address(yulDeployer);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    /* events */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
    event URI(string);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    function setUp() public {
        nftContract = ERC1155Yul(yulDeployer.deployContract("ERC1155Yul"));
    }

    function testMint() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(owner, address(0), alice, 0, 10);
        nftContract.mint(alice, 0, 10);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(owner, address(0), bob, 1, 1);
        nftContract.mint(bob, 1, 1);
        assertEq(nftContract.balanceOf(alice, 0), 10);
        assertEq(nftContract.balanceOf(bob, 1), 1);
        assertEq(nftContract.balanceOf(alice, 1), 0);
    }

    function testBalanceOfBatch() public {
        testMint();
        address[] memory addr = new address[](2);
        uint[] memory ids = new uint[](2);
        uint[] memory res = new uint[](2);
        addr[0] = alice;
        addr[1] = bob;
        ids[0] = 0;
        ids[1] = 1;
        res[0] = 10;
        res[1] = 1;

        assertEq(
            nftContract.balanceOfBatch(addr, ids),
            res
        );
    }

    function testMintBatch() public {
        uint[] memory aliceIds = new uint[](3);
        aliceIds[0] = 0;
        aliceIds[1] = 1;
        aliceIds[2] = 2;
        uint[] memory aliceAmounts = new uint[](3);
        aliceAmounts[0] = 1;
        aliceAmounts[1] = 1;
        aliceAmounts[2] = 2;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(owner, address(0), alice, aliceIds, aliceAmounts);
        nftContract.mintBatch(alice, aliceIds, aliceAmounts);
        uint[] memory bobIds = new uint[](3); // [2, 5, 8]
        bobIds[0] = 2;
        bobIds[1] = 5;
        bobIds[2] = 8;

        uint[] memory bobAmounts = new uint[](3); // [3, 5, 8]
        bobAmounts[0] = 3;
        bobAmounts[1] = 5;
        bobAmounts[2] = 8;
        vm.prank(owner);
        // vm.expectEmit(true, true, true, true);
        nftContract.mintBatch(bob, bobIds, bobAmounts);

        address[] memory addresses = new address[](6);
        addresses[0] = alice;
        addresses[1] = alice;
        addresses[2] = alice;
        addresses[3] = bob;
        addresses[4] = bob;
        addresses[5] = bob;

        uint[] memory ids = new uint[](6);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;
        ids[3] = 2;
        ids[4] = 5;
        ids[5] = 8;

        uint[] memory balances = new uint[](6);
        balances[0] = 1;
        balances[1] = 1;
        balances[2] = 2;
        balances[3] = 3;
        balances[4] = 5;
        balances[5] = 8;

        assertEq(
            nftContract.balanceOfBatch(addresses, ids),
            balances
        );
    }

    function testSafeTransferFrom() external {
        testMint();
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, alice, bob, 0, 3);
        nftContract.safeTransferFrom(alice, bob, 0, 3);
        assertEq(
            nftContract.balanceOf(alice, 0),
            7
        );
        assertEq(
            nftContract.balanceOf(bob, 0),
            3
        );
        assertEq(
            nftContract.balanceOf(bob, 1),
            1
        );
    }

    function testSafeTransferFromBatch() public {
        testMintBatch();
        uint[] memory ids = new uint[](3);
        uint[] memory amounts = new uint[](3);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 2;
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(alice, alice, bob, ids, amounts);
        nftContract.safeTransferFromBatch(alice, bob, ids, amounts);

        uint[] memory aliceAmounts = new uint[](3);
        aliceAmounts[0] = 0;
        aliceAmounts[1] = 0;
        aliceAmounts[2] = 0;
        assertEq(
            nftContract.balanceOfBatch(_makeArray(alice, 3), ids),
            aliceAmounts
        );

        amounts[2] += 3; // initial bob's amount
        assertEq(
            nftContract.balanceOfBatch(_makeArray(bob, 3), ids),
            amounts
        );
    }

    function testSetUri() public {
        string memory uri = "https://cryptokittes.com/";
        string memory uri32 = "http://localhost:123411111111111";
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit URI(uri);
        nftContract.setURI(uri);
        assertEq(
            nftContract.getURI(),
            uri
        );
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit URI(uri32);
        nftContract.setURI(uri32);
        assertEq(
            nftContract.getURI(),
            uri32
        );
    }

    function testApprovals() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(alice, owner, true);
        nftContract.setApprovalForAll(owner, true);
        assertEq(
            nftContract.isApprovedForAll(alice, owner),
            true
        );
        assertEq(
            nftContract.isApprovedForAll(bob, owner),
            false
        );

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(alice, owner, false);
        nftContract.setApprovalForAll(owner, false);
        assertEq(
            nftContract.isApprovedForAll(alice, owner),
            false
        );
    }

    /* utility */

    function _makeArray(uint value, uint length) internal pure returns(uint[] memory) {
        uint[] memory a = new uint[](length);
        for (uint i = 0; i < length; i++) {
            a[i] = value;
        }
        return a;
    }

    function _makeArray(address addr, uint length) internal pure returns(address[] memory) {
        address[] memory a = new address[](length);
        for (uint i = 0; i < length; i++) {
            a[i] = addr;
        }
        return a;
    }
}
