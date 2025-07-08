// SPDX-License-Identifier:MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "../../src/zksync/ZkMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin-contracts/mocks/token/ERC20Mock.sol";
import {Transaction, MemoryTransactionHelper} from "foundry-era-contracts/libraries/MemoryTransactionHelper.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "foundry-era-contracts/Constants.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "foundry-era-contracts/interfaces/IAccount.sol";

contract ZkMinimalAccountTest is Test {
    using MemoryTransactionHelper for Transaction;

    ZkMinimalAccount public minimalAccount;
    ERC20Mock public usdc;

    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address constant ANVIL_DEFAULT_ACCOUNT = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    function setUp() public {
        minimalAccount = new ZkMinimalAccount();
        minimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(minimalAccount), AMOUNT);
    }

    function testZkOwnerCanExecute() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(minimalAccount.owner(), 113, dest, value, functionData);

        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testCanNotZkOwnerExecute() public {
        // Arrange
        address ziad = makeAddr("ziad");
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(minimalAccount.owner(), 113, dest, value, functionData);

        // Act
        vm.prank(ziad);
        vm.expectRevert(ZkMinimalAccount.ZkMinimalAccount__NotFromBootloaderOrOwner.selector);
        minimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
    }

    function testZkValidateTransaction() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(minimalAccount.owner(), 113, dest, value, functionData);
        transaction = _signTransaction(transaction);

        // Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = minimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    // Helpers
    function _signTransaction(Transaction memory transaction) internal view returns (Transaction memory) {
        bytes32 txHash = transaction.encodeHash();

        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, txHash);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);
        return signedTransaction;
    }

    function _createUnsignedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(minimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);

        return Transaction({
            txType: transactionType,
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 993877115,
            gasPerPubdataByteLimit: 993877115,
            maxFeePerGas: 993877115,
            maxPriorityFeePerGas: 993877115,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }
}
